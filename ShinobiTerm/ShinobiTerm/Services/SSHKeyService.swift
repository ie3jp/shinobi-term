import CryptoKit
import Foundation
import Security

struct SSHKeyInfo: Identifiable {
    let id: String
    let name: String
    let publicKey: String
    let fingerprint: String
    let createdAt: Date
}

enum SSHKeyError: Error, LocalizedError {
    case keyNotFound
    case keychainError(OSStatus)
    case invalidKeyData

    var errorDescription: String? {
        switch self {
        case .keyNotFound:
            return "SSH key not found"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .invalidKeyData:
            return "Invalid key data"
        }
    }
}

struct SSHKeyService {
    private static let service = "com.shinobiterm.sshkeys"

    // MARK: - Generate

    static func generateKeyPair(name: String) throws -> SSHKeyInfo {
        let privateKey = Curve25519.Signing.PrivateKey()
        let keyId = UUID().uuidString

        // Store private key raw bytes in Keychain
        let rawKey = privateKey.rawRepresentation
        try savePrivateKey(rawKey, keyId: keyId, name: name)

        let publicKeyString = formatOpenSSHPublicKey(privateKey.publicKey, comment: name)
        let fingerprint = computeFingerprint(privateKey.publicKey)

        return SSHKeyInfo(
            id: keyId,
            name: name,
            publicKey: publicKeyString,
            fingerprint: fingerprint,
            createdAt: Date()
        )
    }

    // MARK: - List

    static func listKeys() -> [SSHKeyInfo] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> SSHKeyInfo? in
            guard let keyId = item[kSecAttrAccount as String] as? String,
                  let name = item[kSecAttrLabel as String] as? String,
                  let createdAt = item[kSecAttrCreationDate as String] as? Date
            else { return nil }

            // Load the private key to derive public key
            guard let privateKey = try? loadPrivateKey(keyId: keyId) else { return nil }
            let publicKeyString = formatOpenSSHPublicKey(privateKey.publicKey, comment: name)
            let fingerprint = computeFingerprint(privateKey.publicKey)

            return SSHKeyInfo(
                id: keyId,
                name: name,
                publicKey: publicKeyString,
                fingerprint: fingerprint,
                createdAt: createdAt
            )
        }
    }

    // MARK: - Load Private Key (for SSH auth only)

    static func loadPrivateKey(keyId: String) throws -> Curve25519.Signing.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            throw SSHKeyError.keyNotFound
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw SSHKeyError.keychainError(status)
        }

        do {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        } catch {
            throw SSHKeyError.invalidKeyData
        }
    }

    // MARK: - Delete

    static func deleteKey(keyId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyId,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SSHKeyError.keychainError(status)
        }
    }

    // MARK: - OpenSSH Format

    private static func formatOpenSSHPublicKey(
        _ publicKey: Curve25519.Signing.PublicKey,
        comment: String
    ) -> String {
        let keyType = "ssh-ed25519"
        let keyTypeData = keyType.data(using: .utf8)!

        var blob = Data()
        // Key type length prefix (big-endian uint32)
        var typeLen = UInt32(keyTypeData.count).bigEndian
        blob.append(Data(bytes: &typeLen, count: 4))
        blob.append(keyTypeData)
        // Public key data length prefix
        var keyLen = UInt32(publicKey.rawRepresentation.count).bigEndian
        blob.append(Data(bytes: &keyLen, count: 4))
        blob.append(publicKey.rawRepresentation)

        return "\(keyType) \(blob.base64EncodedString()) \(comment)"
    }

    private static func computeFingerprint(_ publicKey: Curve25519.Signing.PublicKey) -> String {
        let keyType = "ssh-ed25519"
        let keyTypeData = keyType.data(using: .utf8)!

        var blob = Data()
        var typeLen = UInt32(keyTypeData.count).bigEndian
        blob.append(Data(bytes: &typeLen, count: 4))
        blob.append(keyTypeData)
        var keyLen = UInt32(publicKey.rawRepresentation.count).bigEndian
        blob.append(Data(bytes: &keyLen, count: 4))
        blob.append(publicKey.rawRepresentation)

        let hash = SHA256.hash(data: blob)
        return "SHA256:" + Data(hash).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Private Helpers

    private static func savePrivateKey(_ data: Data, keyId: String, name: String) throws {
        // Delete existing if any
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyId,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyId,
            kSecAttrLabel as String: name,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SSHKeyError.keychainError(status)
        }
    }
}
