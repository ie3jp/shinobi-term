import SwiftData
import SwiftUI

struct ConnectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConnectionProfile.lastConnectedAt, order: .reverse) private var profiles: [ConnectionProfile]
    @StateObject private var connectionManager = SSHConnectionManager()
    @State private var showingAddForm = false
    @State private var showingTmuxAttach = false
    @State private var selectedProfile: ConnectionProfile?
    @State private var activeTerminalProfile: ConnectionProfile?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // tmux Attach button
                tmuxAttachButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Section label
                HStack {
                    Text("SAVED CONNECTIONS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Connection list
                if profiles.isEmpty {
                    emptyState
                } else {
                    connectionList
                }

                Spacer()
            }
            .background(Color(red: 0.05, green: 0.07, blue: 0.09))
            .navigationTitle("Connections")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddForm = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.indigo)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                ConnectionFormView()
            }
            .sheet(item: $selectedProfile) { profile in
                TmuxAttachView(
                    profile: profile,
                    connectionManager: connectionManager
                )
            }
            .fullScreenCover(item: $activeTerminalProfile) { profile in
                if let session = connectionManager.sessions[profile.persistentModelID.hashValue.description] {
                    TerminalContainerView(
                        session: session,
                        profileName: profile.name
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var tmuxAttachButton: some View {
        Button {
            if profiles.count == 1, let profile = profiles.first {
                selectedProfile = profile
            } else {
                showingTmuxAttach = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.title3)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("tmux Attach")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("Connect to Claude Code session")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.25, green: 0.73, blue: 0.31), Color(red: 0.18, green: 0.63, blue: 0.26)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(14)
        }
    }

    private var connectionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(profiles) { profile in
                    connectionRow(profile)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func connectionRow(_ profile: ConnectionProfile) -> some View {
        Button {
            connectToProfile(profile)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Color(white: 0.13))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("\(profile.username)@\(profile.hostname)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 68)
        }
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
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No connections yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to add your first SSH connection")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private func connectToProfile(_ profile: ConnectionProfile) {
        let profileId = profile.persistentModelID.hashValue.description
        let session = connectionManager.createSession(for: profileId)

        Task {
            let password = (try? KeychainService.loadPassword(for: profileId)) ?? ""
            await session.connect(
                hostname: profile.hostname,
                port: profile.port,
                username: profile.username,
                password: password
            )
            profile.lastConnectedAt = Date()
            activeTerminalProfile = profile
        }
    }

    private func deleteProfile(_ profile: ConnectionProfile) {
        let profileId = profile.persistentModelID.hashValue.description
        try? KeychainService.deleteAll(for: profileId)
        connectionManager.removeSession(for: profileId)
        modelContext.delete(profile)
    }
}
