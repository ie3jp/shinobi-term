import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed: \(status)"
        case .loadFailed(let status):
            return "Keychain load failed: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(status)"
        case .unexpectedData:
            return "Unexpected keychain data format"
        }
    }
}

struct KeychainService {
    private static let servicePrefix = "com.shinobiterm"

    private static func service(for profileId: String) -> String {
        "\(servicePrefix).\(profileId)"
    }

    // MARK: - Password

    static func savePassword(_ password: String, for profileId: String) throws {
        let data = Data(password.utf8)
        try saveData(data, service: service(for: profileId), account: "password")
    }

    static func loadPassword(for profileId: String) throws -> String? {
        guard let data = try loadData(service: service(for: profileId), account: "password") else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(for profileId: String) throws {
        try deleteData(service: service(for: profileId), account: "password")
    }

    // MARK: - SSH Key

    static func saveSSHKey(_ key: String, for profileId: String) throws {
        let data = Data(key.utf8)
        try saveData(data, service: service(for: profileId), account: "sshkey")
    }

    static func loadSSHKey(for profileId: String) throws -> String? {
        guard let data = try loadData(service: service(for: profileId), account: "sshkey") else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func deleteSSHKey(for profileId: String) throws {
        try deleteData(service: service(for: profileId), account: "sshkey")
    }

    // MARK: - Delete All Credentials for Profile

    static func deleteAll(for profileId: String) throws {
        try? deletePassword(for: profileId)
        try? deleteSSHKey(for: profileId)
    }

    // MARK: - Generic Keychain Operations

    private static func saveData(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func loadData(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status)
        }
        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }
        return data
    }

    private static func deleteData(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
