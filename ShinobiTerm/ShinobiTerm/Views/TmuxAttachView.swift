import SwiftData
import SwiftUI

struct TmuxAttachView: View {
    let profile: ConnectionProfile
    let connectionManager: SSHConnectionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sessions: [TmuxSession] = []
    @State private var selectedSession: TmuxSession?
    @State private var manualSessionName = ""
    @State private var isLoading = true
    @State private var isConnecting = false
    @State private var showTerminal = false
    @State private var activeSession: SSHSession?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection info
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Connected to \(profile.name) (\(profile.hostname))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)

                if isLoading {
                    ProgressView("Discovering sessions...")
                        .padding(.top, 40)
                    Spacer()
                } else {
                    // Session list
                    if !sessions.isEmpty {
                        sessionListView
                    } else {
                        Text("No tmux sessions found")
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                    }

                    // Divider with "or"
                    HStack(spacing: 12) {
                        Rectangle().fill(.tertiary).frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle().fill(.tertiary).frame(height: 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    // Manual input
                    manualInputSection

                    Spacer()
                }
            }
            .background(Color(white: 0.09))
            .navigationTitle("tmux Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
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
                        profileName: profile.name
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var sessionListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    Button {
                        selectedSession = session
                        attachToSession(session.name)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(session.isAttached ? .green : .secondary)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("\(session.windowCount) window\(session.windowCount == 1 ? "" : "s") · \(session.isAttached ? "attached" : "detached")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedSession?.id == session.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            selectedSession?.id == session.id
                                ? Color.indigo.opacity(0.12)
                                : Color.clear
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var manualInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session name")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g. claude-dev", text: $manualSessionName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                let name = manualSessionName.isEmpty
                    ? (profile.lastTmuxSession ?? "0")
                    : manualSessionName
                attachToSession(name)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text("Attach to Session")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.indigo)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isConnecting)
        }
        .padding(.horizontal, 20)
    }

    private func connectAndListSessions() async {
        let profileId = profile.persistentModelID.hashValue.description
        let session = connectionManager.createSession(for: profileId)

        if session.state != .connected {
            let password = (try? KeychainService.loadPassword(for: profileId)) ?? ""
            await session.connect(
                hostname: profile.hostname,
                port: profile.port,
                username: profile.username,
                password: password
            )
        }

        // Wait a moment for shell to be ready
        try? await Task.sleep(for: .seconds(1))

        sessions = await TmuxService.listSessions(session: session)

        // Pre-select last used session
        if let lastSession = profile.lastTmuxSession {
            selectedSession = sessions.first { $0.name == lastSession }
        }

        isLoading = false
    }

    private func attachToSession(_ sessionName: String) {
        isConnecting = true
        let profileId = profile.persistentModelID.hashValue.description

        guard let session = connectionManager.sessions[profileId] else { return }

        // Save last session name
        profile.lastTmuxSession = sessionName
        try? modelContext.save()

        // Send tmux attach command
        session.send("tmux a -t \(sessionName) 2>/dev/null || tmux new -s \(sessionName)\n")

        activeSession = session
        showTerminal = true
        isConnecting = false
    }
}
