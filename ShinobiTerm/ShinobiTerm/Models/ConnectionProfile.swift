import Foundation
import SwiftData

enum AuthMethod: String, Codable, CaseIterable {
    case password
    case sshKey
}

@Model
final class ConnectionProfile {
    @Attribute(.unique) var profileId: String
    var name: String
    var hostname: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var lastTmuxSession: String?
    var createdAt: Date
    var lastConnectedAt: Date?

    init(
        name: String,
        hostname: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod = .password,
        lastTmuxSession: String? = nil
    ) {
        self.profileId = UUID().uuidString
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.lastTmuxSession = lastTmuxSession
        self.createdAt = Date()
    }
}
