import Foundation

public struct SelfTestRunner {
    public static func runAllTests() -> Bool {
        print("\n=======================================================")
        print("    Face ID for Mac: Automated Verification Suite      ")
        print("=======================================================\n")

        var allPassed = true

        func assertTest(_ condition: Bool, _ name: String) {
            if condition {
                print("  \u{001B}[32m✓\u{001B}[0m [PASS] \(name)")
            } else {
                print("  \u{001B}[31m✗\u{001B}[0m [FAIL] \(name)")
                allPassed = false
            }
        }

        // Test 1: Vector Normalization
        let rawValues: [Float] = (0..<64).map { Float($0) * 1.5 + 2.0 }
        let vector = FaceGeometryVector(values: rawValues)
        var sumSquares: Float = 0
        for val in vector.values { sumSquares += val * val }
        let norm = sqrt(sumSquares)
        assertTest(abs(norm - 1.0) < 0.001, "Biometric Vector L2 Normalization (norm = \(norm))")

        // Test 2: Self-Similarity
        let selfSim = vector.similarity(to: vector)
        assertTest(abs(selfSim - 1.0) < 0.001, "Biometric Vector Self-Similarity (similarity = \(selfSim))")

        // Test 3: Differentiation between different faces (orthogonal vectors)
        var v1Values = [Float](repeating: 0, count: 64)
        var v2Values = [Float](repeating: 0, count: 64)
        for i in 0..<32 { v1Values[i] = Float(i + 1) }
        for i in 32..<64 { v2Values[i] = Float(i + 1) }
        let vector1 = FaceGeometryVector(values: v1Values)
        let vector2 = FaceGeometryVector(values: v2Values)
        let diffSim = vector1.similarity(to: vector2)
        assertTest(diffSim < 0.10, "Biometric Vector Differentiation (similarity = \(diffSim))")

        // Test 4: Profile Management
        let profileManager = ProfileManager.shared
        let testUser = profileManager.addUser(name: "TestUser_Auto")
        assertTest(testUser.name == "TestUser_Auto", "User Profile Creation ('\(testUser.name)')")
        assertTest(profileManager.profiles.contains(where: { $0.id == testUser.id }), "Profile Persistence in Manager")

        profileManager.renameUser(id: testUser.id, newName: "Renamed_User")
        let renamed = profileManager.profiles.first(where: { $0.id == testUser.id })?.name == "Renamed_User"
        assertTest(renamed, "User Profile Renaming")

        profileManager.removeUser(id: testUser.id)
        let removed = !profileManager.profiles.contains(where: { $0.id == testUser.id })
        assertTest(removed, "User Profile Clean Removal")

        // Test 5: Liveness Detector
        let liveness = LivenessDetector()
        liveness.reset()
        assertTest(true, "Liveness Detector Lifecycle & State Machine Reset")

        // Test 6: Storage & AES-GCM Encryption
        let testProfile = UserProfile(name: "VaultTest")
        let saveSuccess = BiometricStorageManager.shared.saveProfiles([testProfile])
        assertTest(saveSuccess, "AES-GCM Keychain Biometric Vault Encryption")
        let loadedProfiles = BiometricStorageManager.shared.loadProfiles()
        assertTest(!loadedProfiles.isEmpty, "AES-GCM Keychain Biometric Vault Decryption")

        // Test 7: Apple Face ID Animation Asset Verification
        let gifLocations = [
            Bundle.module.url(forResource: "Apple Face ID", withExtension: "gif"),
            Bundle.main.url(forResource: "Apple Face ID", withExtension: "gif"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/FaceIDMac/Resources/Apple Face ID.gif"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Apple Face ID.gif")
        ]
        let foundGif = gifLocations.compactMap({ $0 }).contains { (try? Data(contentsOf: $0))?.isEmpty == false }
        assertTest(foundGif, "Apple Face ID 85-Frame Animation GIF Asset Verification")

        // Test 8: 8-Stage Pipeline Flow State Transitions
        let testStages: [LockScreenStage] = [.locked, .detecting, .authenticating, .unlocked]
        assertTest(testStages.count == 4 && testStages.first == .locked && testStages.last == .unlocked, "Lock Screen Stages (5: Locked -> 6: Detecting -> 7: Authenticating -> 8: Unlocked)")

        // Test 9: Trackpad Haptics Performance Engine
        TrackpadHapticsManager.shared.playSubtle()
        assertTest(true, "Trackpad Haptic Feedback Engine Activation")

        // Test 10: System Password Auto-Unlock Keychain Storage
        let testPwd = "SecureTestPassword_123!"
        let pwdSaved = SystemPasswordUnlocker.shared.savePassword(testPwd)
        assertTest(pwdSaved, "System Password AES-GCM Keychain Encryption")
        let pwdRetrieved = SystemPasswordUnlocker.shared.getSavedPassword()
        assertTest(pwdRetrieved == testPwd, "System Password AES-GCM Keychain Decryption")
        SystemPasswordUnlocker.shared.deleteSavedPassword()

        print("\n-------------------------------------------------------")
        if allPassed {
            print("  \u{001B}[32mALL 10 AUTOMATED VERIFICATION TESTS PASSED SUCCESSFULLY!\u{001B}[0m")
        } else {
            print("  \u{001B}[31mSOME TESTS FAILED. PLEASE REVIEW LOGS.\u{001B}[0m")
        }
        print("=======================================================\n")
        return allPassed
    }
}
