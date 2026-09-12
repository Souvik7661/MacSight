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
        SystemPasswordUnlocker.shared.promptToSavePassword()
    }
}

// MARK: - App Delegate for Background Notch Daemon
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.souvik.faceid")
        for app in runningApps where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.terminate()
        }

        // Run as background accessory (No Dock icon, pure notch daemon)
        NSApp.setActivationPolicy(.accessory)

        _ = AutoLockManager.shared
        _ = FaceIDLockWindowManager.shared
        _ = AppLockerMonitor.shared
        _ = LaunchAtLoginManager.shared

        setupLockScreenListeners()

        // Begin Onboarding Sequence:
        // 1. Accessibility (PC Control) -> 2. Camera Access -> 3. Password Setup -> 4. Notch Dynamic Island
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
                if !ProfileManager.shared.isAnyUserEnrolled {
                    FaceIDLockWindowManager.shared.presentNotchEnrollment()
                }

                // Step 4: If password is not saved yet, prompt user so Face ID can auto-unlock
                if !SystemPasswordUnlocker.shared.hasSavedPassword() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        SystemPasswordUnlocker.shared.promptToSavePassword()
                    }
                }
            }
        }
    }

    private func setupLockScreenListeners() {
        let wsCenter = NSWorkspace.shared.notificationCenter
        let distCenter = DistributedNotificationCenter.default()

        // Screen Sleep & Wake observers
        wsCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )

        wsCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        // Distributed notifications for macOS lock/unlock & screensaver
        distCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        distCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        distCenter.addObserver(
            self,
            selector: #selector(handleScreenWake),
            name: NSNotification.Name("com.souvik.faceid.triggerNotch"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        distCenter.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        distCenter.addObserver(
            self,
            selector: #selector(handlePromptPassword),
            name: NSNotification.Name("com.souvik.faceid.promptPassword"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func handlePromptPassword() {
        DispatchQueue.main.async {
            SystemPasswordUnlocker.shared.promptToSavePassword()
        }
    }

    @objc private func handleScreenWake() {
        // When screen wakes up, present Dynamic Island down the notch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            FaceIDLockWindowManager.shared.presentDynamicIslandNotch()
        }
    }

    @objc private func handleScreenUnlocked() {
        // When Mac unlocks
        FaceIDLockWindowManager.shared.dismissLockOverlay()
    }
}
