import Foundation

@MainActor
final class SSHConnectionManager: ObservableObject {
    @Published var sessions: [String: SSHSession] = [:]

    func createSession(for profileId: String) -> SSHSession {
        if let existing = sessions[profileId] {
            return existing
        }
        let session = SSHSession()
        sessions[profileId] = session
        return session
    }

    func removeSession(for profileId: String) {
        if let session = sessions[profileId] {
            session.disconnect()
            sessions.removeValue(forKey: profileId)
        }
    }

    func disconnectAll() {
        for (_, session) in sessions {
            session.disconnect()
        }
        sessions.removeAll()
    }
}
