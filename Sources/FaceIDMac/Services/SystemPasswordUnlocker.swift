import Foundation
import CoreGraphics
import Security
import CryptoKit
import AppKit

public final class SystemPasswordUnlocker: ObservableObject {
    public static let shared = SystemPasswordUnlocker()

    private var passwordVaultURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("FaceIDMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".pwd.vault")
    }

    @Published public var isAutoUnlockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAutoUnlockEnabled, forKey: "enableSystemPasswordAutoUnlock")
        }
    }

    public init() {
        if UserDefaults.standard.object(forKey: "enableSystemPasswordAutoUnlock") == nil {
            UserDefaults.standard.set(true, forKey: "enableSystemPasswordAutoUnlock")
        }
        self.isAutoUnlockEnabled = UserDefaults.standard.bool(forKey: "enableSystemPasswordAutoUnlock")
    }

    // MARK: - Encrypted Password Storage via AES-256-GCM
    public func savePassword(_ password: String) -> Bool {
        deleteSavedPassword()

        guard let key = BiometricStorageManager.shared.getOrCreateSymmetricKey(),
              let data = password.data(using: .utf8) else { return false }

        do {
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { return false }
            try combined.write(to: passwordVaultURL, options: .completeFileProtection)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: passwordVaultURL.path)
            return true
        } catch {
            return false
        }
    }

    public func getSavedPassword() -> String? {
        guard let key = BiometricStorageManager.shared.getOrCreateSymmetricKey(),
              let encryptedData = try? Data(contentsOf: passwordVaultURL) else { return nil }

        do {
            let box = try AES.GCM.SealedBox(combined: encryptedData)
            let decrypted = try AES.GCM.open(box, using: key)
            return String(data: decrypted, encoding: .utf8)
        } catch {
            return nil
        }
    }

    public func hasSavedPassword() -> Bool {
        return getSavedPassword() != nil
    }

    public func deleteSavedPassword() {
        try? FileManager.default.removeItem(at: passwordVaultURL)
    }

    // MARK: - Keystroke Synthesis & Automatic Password Entry
    /// Automatically types the stored password into the native macOS lock screen password box
    public func typePasswordAndSubmit(completion: (() -> Void)? = nil) {
        guard isAutoUnlockEnabled, let password = getSavedPassword(), !password.isEmpty else {
            completion?()
            return
        }

        // Dispatch keystrokes in background queue with natural timing
        DispatchQueue.global(qos: .userInteractive).async {
            // Give window manager a moment to yield focus to the login field
            usleep(150_000) // 150ms

            for char in password {
                let utf16Chars = Array(String(char).utf16)
                if let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                   let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                    eventDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
                    eventUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)

                    eventDown.post(tap: .cghidEventTap)
                    usleep(18_000) // 18ms key press duration
                    eventUp.post(tap: .cghidEventTap)
                    usleep(12_000) // 12ms inter-key delay
                }
            }

            // Press Return Key (Virtual Keycode 0x24 / 36)
            usleep(60_000) // 60ms pause before Enter
            let returnKeyCode: CGKeyCode = 0x24
            if let returnDown = CGEvent(keyboardEventSource: nil, virtualKey: returnKeyCode, keyDown: true),
               let returnUp = CGEvent(keyboardEventSource: nil, virtualKey: returnKeyCode, keyDown: false) {
                returnDown.post(tap: .cghidEventTap)
                usleep(25_000)
                returnUp.post(tap: .cghidEventTap)
            }

            DispatchQueue.main.async {
                TrackpadHapticsManager.shared.playSuccess()
                completion?()
            }
        }
    }
}
