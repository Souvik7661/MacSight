import SwiftUI
import AppKit

public struct FaceIDMenuBarContent: View {
    @ObservedObject public var profileManager = ProfileManager.shared
    @ObservedObject public var autoLock = AutoLockManager.shared

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "faceid")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(appleGreen)

                Text("Face ID for Mac")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(appleGreen)
                        .frame(width: 7, height: 7)
                    Text("Down Notch")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(appleGreen)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Quick Actions
            Button(action: {
                FaceIDLockWindowManager.shared.presentDynamicIslandNotch()
            }) {
                Label("Test Face ID Lock (⌘L)", systemImage: "lock.fill")
            }
            .keyboardShortcut("l", modifiers: .command)

            Button(action: {
                FaceIDLockWindowManager.shared.presentNotchEnrollment()
            }) {
                Label("Re-scan Face (Notch)", systemImage: "person.crop.circle.badge.plus")
            }

            Button(action: {
                PasswordSetupHelper.promptForPassword()
            }) {
                Label(
                    SystemPasswordUnlocker.shared.hasSavedPassword() ? "Change Mac Password" : "⚠️ Set Mac Password (Auto-Unlock)",
                    systemImage: SystemPasswordUnlocker.shared.hasSavedPassword() ? "key.fill" : "exclamationmark.triangle.fill"
                )
            }

            Button(action: {
                SettingsWindowManager.shared.showSettings()
            }) {
                Label("Preferences / Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Face ID") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 250)
    }
}
