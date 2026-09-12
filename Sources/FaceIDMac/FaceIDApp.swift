import SwiftUI
import AppKit
import AVFoundation

@main
struct FaceIDApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        if CommandLine.arguments.contains("--test") {
            let success = SelfTestRunner.runAllTests()
            exit(success ? 0 : 1)
        }
    }

    var body: some Scene {
        MenuBarExtra("Face ID", systemImage: "faceid") {
            FaceIDMenuBarContent()
        }
    }
}

// MARK: - Standalone Helpers
public final class SettingsWindowManager {
    public static let shared = SettingsWindowManager()
    private var window: NSWindow?

    public func showSettings() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Face ID Preferences"
            win.center()
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: SettingsView(onReEnroll: {
                self.window?.close()
                FaceIDLockWindowManager.shared.presentNotchEnrollment()
            }))
            self.window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

public final class PasswordSetupHelper {
    public static func promptForPassword() {
        let alert = NSAlert()
        alert.messageText = "Set Lock Screen Password"
        alert.informativeText = "Enter your Mac account password so Face ID can automatically unlock your Mac down the notch. Stored securely in a local AES-256-GCM encrypted vault."
        alert.alertStyle = .informational
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "Mac login password"
        alert.accessoryView = input
        alert.addButton(withTitle: "Save Password")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let pwd = input.stringValue
            if !pwd.isEmpty {
                _ = SystemPasswordUnlocker.shared.savePassword(pwd)
            }
        }
    }
}

// MARK: - App Delegate for Background Notch Daemon
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background accessory (No Dock icon, pure notch daemon)
        NSApp.setActivationPolicy(.accessory)

        _ = AutoLockManager.shared
        _ = FaceIDLockWindowManager.shared
        _ = AppLockerMonitor.shared
        _ = LaunchAtLoginManager.shared

        setupLockScreenListeners()

        // Begin Onboarding Sequence:
        // 1. Accessibility (PC Control) -> 2. Camera Access -> 3. Notch Dynamic Island Enrollment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.startOnboardingSequence()
        }
    }

    private func startOnboardingSequence() {
        // Step 1: Request PC Control (Accessibility)
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(promptOptions)

        // Step 2: Request Camera Access
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                // Step 3: Implement Face ID down the notch!
                // If not enrolled yet, drop down notch for instant enrollment
                if !ProfileManager.shared.isAnyUserEnrolled {
                    FaceIDLockWindowManager.shared.presentNotchEnrollment()
                }
            }
        }
    }

    private func setupLockScreenListeners() {
        // Screen Sleep & Wake observers
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        // Distributed notifications for macOS lock/unlock
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSNotification.Name("com.souvik.faceid.triggerNotch"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func handleScreenWake() {
        // When screen wakes up, present Dynamic Island down the notch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            FaceIDLockWindowManager.shared.presentDynamicIslandNotch()
        }
    }

    @objc private func handleScreenLocked() {
        // When Mac locks, prepare Face ID
    }

    @objc private func handleScreenUnlocked() {
        // When Mac unlocks
        FaceIDLockWindowManager.shared.dismissLockOverlay()
    }
}
