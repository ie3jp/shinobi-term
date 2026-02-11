import CryptoKit
import SwiftData
import SwiftUI

struct TmuxAttachView: View {
    let profile: ConnectionProfile
    let connectionManager: SSHConnectionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sessions: [TmuxSession] = []
    @State private var manualSessionName = ""
    @State private var isLoading = true
    @State private var isConnecting = false
    @State private var showTerminal = false
    @State private var activeSession: SSHSession?
    @State private var tmuxCommand: String?
    @State private var connectionError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Host info bar
                    hostInfoBar

                    if isLoading {
                        ProgressView()
                            .tint(Color("greenPrimary"))
                            .padding(.top, 40)
                    } else {
                        // Active sessions
                        sessionsSection

                        // Manual attach
                        manualAttachSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .background(Color("bgPage"))
        .navigationTitle("tmux_sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshSessions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(Color("textTertiary"))
                }
            }
        }
        .task {
            await connectAndListSessions()
        }
        .fullScreenCover(isPresented: $showTerminal) {
            if let session = activeSession {
                TerminalContainerView(
                    session: session,
                    profileName: profile.name,
                    tmuxSession: profile.lastTmuxSession,
                    initialCommand: tmuxCommand
                )
            } else {
                Text("Session not found")
                    .foregroundStyle(Color("textMuted"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
            }
        }
        .alert("connection error", isPresented: showConnectionError) {
            Button("Copy") {
                UIPasteboard.general.string = connectionError
                connectionError = nil
            }
            Button("OK") { connectionError = nil }
        } message: {
            Text(connectionError ?? "")
        }
        .preferredColorScheme(.dark)
    }

    private var showConnectionError: Binding<Bool> {
        Binding(
            get: { connectionError != nil },
            set: { if !$0 { connectionError = nil } }
        )
    }

    // MARK: - Host Info

    private var hostInfoBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 16))
                .foregroundStyle(Color("greenPrimary"))
            Text(profile.name)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color("textPrimary"))
            Text("// \(profile.username)@\(profile.hostname)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color("textMuted"))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("bgSurface"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("borderPrimary"), lineWidth: 1)
        )
    }

    // MARK: - Sessions List

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("// active_sessions")

            if sessions.isEmpty {
                HStack {
                    Spacer()
                    Text("no tmux sessions found")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: TmuxSession) -> some View {
        Button {
            attachToSession(session.name)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("greenPrimary"))
                    .frame(width: 36, height: 36)
                    .background(Color("bgElevated"))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("textPrimary"))
                    Text("\(session.windowCount) window\(session.windowCount == 1 ? "" : "s") · \(session.isAttached ? "attached" : "detached")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))
                }

                Spacer()

                Circle()
                    .fill(session.isAttached ? Color("greenPrimary") : Color("textMuted"))
                    .frame(width: 8, height: 8)
            }
            .padding(12)
            .background(Color("bgSurface"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual Attach

    private var manualAttachSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("// manual_attach")

            HStack(spacing: 8) {
                TextField("session_name", text: $manualSessionName)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color("textPrimary"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color("bgInput"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color("borderPrimary"), lineWidth: 1)
                    )

                Button {
                    let name = manualSessionName.isEmpty
                        ? (profile.lastTmuxSession ?? "0")
                        : manualSessionName
                    attachToSession(name)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color("greenPrimary"))
                        .cornerRadius(8)
                }
                .disabled(isConnecting)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color("textTertiary"))
    }

    private func connectAndListSessions() async {
        let profileId = profile.profileId
        let session = connectionManager.createSession(for: profileId)

        if session.state != .connected {
            await connectSession(session, profile: profile)
        }

        if case .error(let message) = session.state {
            connectionError = message
            isLoading = false
            return
        }

        try? await Task.sleep(for: .seconds(2))
        sessions = await TmuxService.listSessions(session: session)
        isLoading = false
    }

    private func refreshSessions() async {
        isLoading = true
        let profileId = profile.profileId
        if let session = connectionManager.sessions[profileId] {
            sessions = await TmuxService.listSessions(session: session)
        }
        isLoading = false
    }

    private func attachToSession(_ sessionName: String) {
        isConnecting = true
        let profileId = profile.profileId

        guard let session = connectionManager.sessions[profileId] else { return }

        profile.lastTmuxSession = sessionName
        try? modelContext.save()

        tmuxCommand = "tmux a -t \(sessionName) 2>/dev/null || tmux new -s \(sessionName)\n"

        if session.state == .connected {
            activeSession = session
            showTerminal = true
            isConnecting = false
        } else {
            // Reconnect if session was disconnected
            Task {
                await connectSession(session, profile: profile)
                if case .error(let message) = session.state {
                    connectionError = message
                    isConnecting = false
                    return
                }
                if session.state == .connected {
                    activeSession = session
                    showTerminal = true
                }
                isConnecting = false
            }
        }
    }

    private func connectSession(_ session: SSHSession, profile: ConnectionProfile) async {
        switch profile.authMethod {
        case .password:
            let password = (try? KeychainService.loadPassword(for: profile.profileId)) ?? ""
            await session.connect(
                hostname: profile.hostname,
                port: profile.port,
                username: profile.username,
                password: password
            )
        case .sshKey:
            guard let keyId = profile.sshKeyId else {
                connectionError = "No SSH key selected. Go to Settings > SSH Keys to generate one, or switch to password auth."
                return
            }
            guard let privateKey = try? SSHKeyService.loadPrivateKey(keyId: keyId) else {
                connectionError = "SSH key not found in Keychain. It may have been deleted. Re-generate in Settings > SSH Keys."
                return
            }
            await session.connect(
                hostname: profile.hostname,
                port: profile.port,
                username: profile.username,
                authMethod: .sshKey,
                privateKey: privateKey
            )
        }
    }
}
