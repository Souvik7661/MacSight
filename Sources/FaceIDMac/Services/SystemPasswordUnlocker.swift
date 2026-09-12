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

    public func promptToSavePassword(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Enable Automatic Lock Screen Unlock"
            alert.informativeText = "Enter your Mac account password once. It is stored in your local AES-256 encrypted vault so Face ID can automatically unlock your Mac without needing Touch ID or manual typing."
            alert.alertStyle = .informational

            let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
            input.placeholderString = "Mac Account Password"
            alert.accessoryView = input
            alert.addButton(withTitle: "Save Password")
            alert.addButton(withTitle: "Cancel")

            NSApp.activate(ignoringOtherApps: true)
            let res = alert.runModal()
            if res == .alertFirstButtonReturn {
                let pwd = input.stringValue
                if !pwd.isEmpty {
                    _ = self.savePassword(pwd)
                }
            }
            completion?()
        }
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
            // 1. Wake up the password field if screen was asleep
            if let screen = NSScreen.main {
                let midPoint = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
                let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: midPoint, mouseButton: .left)
                moveEvent?.post(tap: .cghidEventTap)
            }

            usleep(250_000) // 250ms for login field focus

            // 2. Type characters using both virtual keycodes and unicode
            for char in password {
                let utf16Chars = Array(String(char).utf16)
                let keyCode = self.keyCodeFor(character: char)

                if let eventDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                   let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                    eventDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
                    eventUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)

                    if char.isUppercase || "~!@#$%^&*()_+{}|:\"<>?".contains(char) {
                        eventDown.flags = .maskShift
                        eventUp.flags = .maskShift
                    }

                    eventDown.post(tap: .cghidEventTap)
                    usleep(18_000) // 18ms key press duration
                    eventUp.post(tap: .cghidEventTap)
                    usleep(12_000) // 12ms inter-key delay
                }
            }

            // 3. Press Return Key (Virtual Keycode 0x24 / 36)
            usleep(70_000) // 70ms pause before Enter
            let returnKeyCode: CGKeyCode = 0x24
            if let returnDown = CGEvent(keyboardEventSource: nil, virtualKey: returnKeyCode, keyDown: true),
               let returnUp = CGEvent(keyboardEventSource: nil, virtualKey: returnKeyCode, keyDown: false) {
                returnDown.post(tap: .cghidEventTap)
                usleep(25_000)
                returnUp.post(tap: .cghidEventTap)
            }

            // 4. Fallback Return press after 160ms if needed
            usleep(160_000)
            if let returnDown2 = CGEvent(keyboardEventSource: nil, virtualKey: returnKeyCode, keyDown: true),
               let returnUp2 = CGEvent(keyboardEventSource: nil, virtualKey: returnKeyCode, keyDown: false) {
                returnDown2.post(tap: .cghidEventTap)
                usleep(25_000)
                returnUp2.post(tap: .cghidEventTap)
            }

            DispatchQueue.main.async {
                TrackpadHapticsManager.shared.playSuccess()
                completion?()
            }
        }
    }

    private func keyCodeFor(character: Character) -> CGKeyCode {
        let lower = character.lowercased().first ?? character
        switch lower {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1", "!": return 0x12
        case "2", "@": return 0x13
        case "3", "#": return 0x14
        case "4", "$": return 0x15
        case "6", "^": return 0x16
        case "5", "%": return 0x17
        case "=", "+": return 0x18
        case "9", "(": return 0x19
        case "7", "&": return 0x1A
        case "-", "_": return 0x1B
        case "8", "*": return 0x1C
        case "0", ")": return 0x1D
        case "]", "}": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[", "{": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'", "\"": return 0x27
        case "k": return 0x28
        case ";", ":": return 0x29
        case "\\", "|": return 0x2A
        case ",", "<": return 0x2B
        case "/", "?": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".", ">": return 0x2F
        case " ": return 0x31
        default: return 0x00
        }
    }
}
