import SwiftData
import SwiftUI

struct ConnectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectionProfile.lastConnectedAt, order: .reverse) private var profiles: [ConnectionProfile]
    @StateObject private var connectionManager = SSHConnectionManager()
    @State private var showingAddForm = false
    @State private var selectedTmuxProfile: ConnectionProfile?
    @State private var activeTerminalProfile: ConnectionProfile?
    @State private var quickConnectText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Nav bar
                navBar

                ScrollView {
                    VStack(spacing: 12) {
                        // Quick attach section
                        quickAttachSection

                        // Connections section
                        connectionsSection

                        // Quick connect section
                        quickConnectSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .background(Color("bgPage"))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showingAddForm) {
                ConnectionFormView()
            }
            .navigationDestination(item: $selectedTmuxProfile) { profile in
                TmuxAttachView(
                    profile: profile,
                    connectionManager: connectionManager
                )
            }
            .fullScreenCover(item: $activeTerminalProfile) { profile in
                let profileId = profile.profileId
                if let session = connectionManager.sessions[profileId] {
                    TerminalContainerView(
                        session: session,
                        profileName: profile.name,
                        tmuxSession: profile.lastTmuxSession
                    )
                } else {
                    Text("Session not found")
                        .foregroundStyle(Color("textMuted"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                }
            }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Text("shinobi_term")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(Color("textTertiary"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Quick Attach

    private var quickAttachSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("// quick_attach")

            Button {
                if profiles.count == 1, let profile = profiles.first {
                    selectedTmuxProfile = profile
                } else if profiles.count > 1 {
                    // Show profile picker for tmux
                    selectedTmuxProfile = profiles.first
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    Text("tmux attach")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [Color("greenPrimary"), Color("greenPrimary").opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Connections

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("// connections")
                Spacer()
                Button {
                    showingAddForm = true
                } label: {
                    Text("+ add")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))
                }
            }

            if profiles.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(profiles) { profile in
                        connectionCard(profile)
                    }
                }
            }
        }
    }

    private func connectionCard(_ profile: ConnectionProfile) -> some View {
        Button {
            connectToProfile(profile)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("greenPrimary"))
                    .frame(width: 40, height: 40)
                    .background(Color("bgSurface"))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color("textPrimary"))
                    Text("\(profile.username)@\(profile.hostname):\(profile.port)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color("textMuted"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color("textTertiary"))
            }
            .padding(12)
            .background(Color("bgSurface"))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color("borderPrimary"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") {
                // TODO: Edit profile
            }
            Button(role: .destructive) {
                deleteProfile(profile)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 32))
                .foregroundStyle(Color("textTertiary"))
            Text("no connections yet")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color("textMuted"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Quick Connect

    private var quickConnectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("// quick_connect")

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("textTertiary"))
                    TextField("user@host:port", text: $quickConnectText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color("textPrimary"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color("bgSurface"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("borderPrimary"), lineWidth: 1)
                )

                Button {
                    quickConnect()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color("greenPrimary"))
                        .cornerRadius(8)
                }
                .disabled(quickConnectText.isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color("textTertiary"))
    }

    private func connectToProfile(_ profile: ConnectionProfile) {
        let profileId = profile.profileId
        let session = connectionManager.createSession(for: profileId)

        Task {
            let password = (try? KeychainService.loadPassword(for: profileId)) ?? ""
            await session.connect(
                hostname: profile.hostname,
                port: profile.port,
                username: profile.username,
                password: password
            )
            guard session.state == .connected else { return }
            profile.lastConnectedAt = Date()
            activeTerminalProfile = profile
        }
    }

    private func quickConnect() {
        // Parse "user@host:port" format
        let text = quickConnectText
        guard let atIndex = text.firstIndex(of: "@") else { return }
        let username = String(text[text.startIndex..<atIndex])
        let rest = String(text[text.index(after: atIndex)...])
        let parts = rest.split(separator: ":", maxSplits: 1)
        let hostname = String(parts[0])
        let port = parts.count > 1 ? Int(parts[1]) ?? 22 : 22

        let session = connectionManager.createSession(for: "quick-\(hostname)")
        Task {
            await session.connect(
                hostname: hostname,
                port: port,
                username: username,
                password: ""
            )
            guard session.state == .connected else { return }
            // Create a temporary profile for the terminal view
            let profile = ConnectionProfile(
                name: hostname,
                hostname: hostname,
                port: port,
                username: username
            )
            modelContext.insert(profile)
            profile.lastConnectedAt = Date()
            activeTerminalProfile = profile
        }
    }

    private func deleteProfile(_ profile: ConnectionProfile) {
        let profileId = profile.profileId
        try? KeychainService.deleteAll(for: profileId)
        connectionManager.removeSession(for: profileId)
        modelContext.delete(profile)
    }
}
