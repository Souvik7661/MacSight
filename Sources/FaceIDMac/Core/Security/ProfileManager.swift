import Foundation
import Combine

public final class ProfileManager: ObservableObject {
    public static let shared = ProfileManager()

    @Published public var profiles: [UserProfile] = []
    @Published public var activeUserId: UUID

    private let storage = BiometricStorageManager.shared

    public init() {
        let loaded = storage.loadProfiles()
        self.profiles = loaded
        self.activeUserId = loaded.first?.id ?? UUID()
    }

    public var activeUser: UserProfile? {
        profiles.first(where: { $0.id == activeUserId }) ?? profiles.first
    }

    public var isAnyUserEnrolled: Bool {
        profiles.contains(where: { $0.isEnrolled })
    }

    public func addUser(name: String) -> UserProfile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New User" : trimmed
        let newUser = UserProfile(name: finalName)
        profiles.append(newUser)
        activeUserId = newUser.id
        save()
        return newUser
    }

    public func renameUser(id: UUID, newName: String) {
        if let idx = profiles.firstIndex(where: { $0.id == id }) {
            profiles[idx].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            save()
        }
    }

    public func removeUser(id: UUID) {
        profiles.removeAll(where: { $0.id == id })
        if profiles.isEmpty {
            let defaultUser = UserProfile(name: "Souvik")
            profiles = [defaultUser]
        }
        if !profiles.contains(where: { $0.id == activeUserId }) {
            activeUserId = profiles.first!.id
        }
        save()
    }

    public func saveTemplates(for userId: UUID, templates: [EnrolledTemplate]) {
        if let idx = profiles.firstIndex(where: { $0.id == userId }) {
            profiles[idx].templates = templates
            save()
        }
    }

    public func recordAuthentication(for userId: UUID) {
        if let idx = profiles.firstIndex(where: { $0.id == userId }) {
            profiles[idx].lastAuthenticated = Date()
            save()
        }
    }

    public func deleteAllBiometricData() {
        storage.deleteAllBiometricData()
        let freshUser = UserProfile(name: "Souvik")
        profiles = [freshUser]
        activeUserId = freshUser.id
    }

    private func save() {
        _ = storage.saveProfiles(profiles)
    }
}
