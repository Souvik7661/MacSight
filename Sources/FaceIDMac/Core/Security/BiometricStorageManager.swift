import Foundation
import CryptoKit
import Security

public struct EnrolledTemplate: Codable, Equatable, Sendable {
    public let id: UUID
    public let label: String
    public let vector: FaceGeometryVector
    public let enrolledAt: Date

    public init(id: UUID = UUID(), label: String, vector: FaceGeometryVector, enrolledAt: Date = Date()) {
        self.id = id
        self.label = label
        self.vector = vector
        self.enrolledAt = enrolledAt
    }
}

public struct UserProfile: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var templates: [EnrolledTemplate]
    public var createdAt: Date
    public var lastAuthenticated: Date?

    public init(id: UUID = UUID(), name: String, templates: [EnrolledTemplate] = [], createdAt: Date = Date(), lastAuthenticated: Date? = nil) {
        self.id = id
        self.name = name
        self.templates = templates
        self.createdAt = createdAt
        self.lastAuthenticated = lastAuthenticated
    }

    public var isEnrolled: Bool {
        return !templates.isEmpty
    }
}

public final class BiometricStorageManager: @unchecked Sendable {
    public static let shared = BiometricStorageManager()

    private let keychainService = "com.souvik.faceidformac.biometrics"
    private let keychainAccount = "encryptionKey"
    private let lock = NSLock()

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("FaceIDMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("biometrics.vault")
    }

    public init() {}

    // MARK: - Key Management via Secure Vault Keyfile
    public func getOrCreateSymmetricKey() -> SymmetricKey? {
        let keyURL = storageURL.deletingLastPathComponent().appendingPathComponent(".vault.key")
        if let data = try? Data(contentsOf: keyURL), data.count == 32 {
            return SymmetricKey(data: data)
        }

        // Generate new 256-bit AES key
        let newKey = SymmetricKey(size: .bits256)
        let rawKeyData = newKey.withUnsafeBytes { Data($0) }
        try? rawKeyData.write(to: keyURL, options: .completeFileProtection)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        return newKey
    }

    // MARK: - Save and Load Profiles
    public func saveProfiles(_ profiles: [UserProfile]) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let key = getOrCreateSymmetricKey() else { return false }

        do {
            let data = try JSONEncoder().encode(profiles)
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else { return false }
            try combined.write(to: storageURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func loadProfiles() -> [UserProfile] {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            // Default first user
            return [UserProfile(name: "Souvik")]
        }

        guard let key = getOrCreateSymmetricKey() else { return [] }

        do {
            let encryptedData = try Data(contentsOf: storageURL)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            let profiles = try JSONDecoder().decode([UserProfile].self, from: decryptedData)
            return profiles.isEmpty ? [UserProfile(name: "Souvik")] : profiles
        } catch {
            return [UserProfile(name: "Souvik")]
        }
    }

    // MARK: - Secure Purge ("Delete Face ID Data")
    public func deleteAllBiometricData() {
        lock.lock()
        defer { lock.unlock() }

        // 1. Delete encrypted file
        try? FileManager.default.removeItem(at: storageURL)

        // 2. Delete Keychain entry
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
