import SwiftUI
import AVFoundation

public struct SettingsView: View {
    @ObservedObject public var profileManager = ProfileManager.shared
    @ObservedObject public var matchEngine = BiometricMatchEngine.shared
    @ObservedObject public var autoLock = AutoLockManager.shared
    @ObservedObject public var appLocker = AppLockerMonitor.shared
    @ObservedObject public var launchManager = LaunchAtLoginManager.shared
    @ObservedObject public var notificationManager = NotificationManager.shared

    public var onReEnroll: (() -> Void)?

    @State private var selectedTab: SettingsTab = .general
    @State private var showDeleteConfirmation: Bool = false
    @State private var newUserName: String = ""
    @State private var systemPasswordInput: String = ""
    @State private var showAddUserSheet: Bool = false

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case faceID = "Face ID"
        case security = "Security"
        case protectedApps = "Protected Apps"
        case users = "Users"
        case privacy = "Privacy"
        case advanced = "Advanced"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .general: return "gearshape"
            case .faceID: return "faceid"
            case .security: return "lock.shield"
            case .protectedApps: return "apps.ipad"
            case .users: return "person.2"
            case .privacy: return "hand.raised.fill"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    public init(onReEnroll: (() -> Void)? = nil) {
        self.onReEnroll = onReEnroll
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180, maxWidth: 200)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .general:
                            generalSection
                        case .faceID:
                            faceIDSection
                        case .security:
                            securitySection
                        case .protectedApps:
                            protectedAppsSection
                        case .users:
                            usersSection
                        case .privacy:
                            privacySection
                        case .advanced:
                            advancedSection
                        }
                    }
                    .padding(24)
                }
            }
            .frame(minWidth: 460)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 700, height: 500)
        .sheet(isPresented: $showAddUserSheet) {
            addUserSheet
        }
        .alert("Delete All Face ID Data?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                profileManager.deleteAllBiometricData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all enrolled biometric templates and encryption keys from this Mac. This action cannot be undone.")
        }
    }

    // MARK: - General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("Launch at Login", isOn: Binding(
                get: { launchManager.isEnabled },
                set: { launchManager.setEnabled($0) }
            ))

            Toggle("Enable Native Notifications", isOn: $notificationManager.isNotificationsEnabled)

            Toggle("Play Apple System Sound Effects", isOn: Binding(
                get: { AudioFeedback.shared.isEnabled },
                set: { AudioFeedback.shared.isEnabled = $0 }
            ))

            Toggle("Trackpad Haptic Feedback (Physical Click)", isOn: Binding(
                get: { TrackpadHapticsManager.shared.isHapticsEnabled },
                set: { TrackpadHapticsManager.shared.isHapticsEnabled = $0 }
            ))
        }
    }

    // MARK: - Face ID Section
    private var faceIDSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Unlock HUD Experience", selection: Binding(
                get: { FaceIDLockWindowManager.shared.preferredUIMode },
                set: { FaceIDLockWindowManager.shared.preferredUIMode = $0 }
            )) {
                Text("🏝️ Notch & Dynamic Island").tag(UnlockUIMode.dynamicIsland)
                Text("🖥️ Full-Screen Lock Screen").tag(UnlockUIMode.fullScreenLock)
            }
            .pickerStyle(.segmented)

            Toggle("Require Liveness Check (Anti-Spoofing)", isOn: $matchEngine.settings.requireLiveness)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Recognition Sensitivity:")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(String(format: "%.2f", matchEngine.settings.sensitivityThreshold))
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }

                Slider(value: $matchEngine.settings.sensitivityThreshold, in: 0.80...0.96, step: 0.02)
                HStack {
                    Text("Faster (0.80)").font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                    Text("Conservative (0.96)").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enrolled Templates")
                        .font(.system(size: 13, weight: .medium))
                    Text("\(profileManager.activeUser?.templates.count ?? 0) biometric angle samples captured.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Re-Enroll Face") {
                    onReEnroll?()
                }
            }
        }
    }

    // MARK: - Security Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("Lock workspace when leaving Mac", isOn: $autoLock.isAutoLockEnabled)

            Picker("Auto-Lock Timeout", selection: $autoLock.lockTimeoutMinutes) {
                Text("1 Minute").tag(1)
                Text("5 Minutes").tag(5)
                Text("15 Minutes").tag(15)
                Text("30 Minutes").tag(30)
                Text("Never").tag(0)
            }
            .pickerStyle(.menu)

            Divider()

            // System Password Auto-Unlock (Glance feature)
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Auto-Type Password on Native macOS Lock Screen", isOn: Binding(
                    get: { SystemPasswordUnlocker.shared.isAutoUnlockEnabled },
                    set: { SystemPasswordUnlocker.shared.isAutoUnlockEnabled = $0 }
                ))

                Text("When your face is recognized, Face ID automatically enters your stored password into the native macOS lock screen and presses Return.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    SecureField(
                        SystemPasswordUnlocker.shared.hasSavedPassword() ? "•••••••••••• (Password Saved)" : "Enter Mac Account Password",
                        text: $systemPasswordInput
                    )
                    .textFieldStyle(.roundedBorder)

                    Button("Save in Keychain") {
                        if !systemPasswordInput.isEmpty {
                            _ = SystemPasswordUnlocker.shared.savePassword(systemPasswordInput)
                            systemPasswordInput = ""
                        }
                    }
                    .disabled(systemPasswordInput.isEmpty)

                    if SystemPasswordUnlocker.shared.hasSavedPassword() {
                        Button("Clear") {
                            SystemPasswordUnlocker.shared.deleteSavedPassword()
                        }
                    }
                }
            }

            Divider()

            Picker("Max Failed Recognition Attempts", selection: $matchEngine.settings.maxFailedAttempts) {
                Text("3 Attempts").tag(3)
                Text("5 Attempts").tag(5)
                Text("10 Attempts").tag(10)
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 4) {
                Text("Fallback Authentication")
                    .font(.system(size: 13, weight: .medium))
                Text("When Face ID fails or camera is unavailable, macOS Touch ID or System Administrator password is used.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Protected Apps Section
    private var protectedAppsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Protected Applications")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button("Add Other Application…") {
                    selectCustomApp()
                }
            }

            List {
                ForEach(appLocker.protectedApps) { app in
                    HStack {
                        Text(app.name)
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { app.isProtected },
                            set: { _ in appLocker.toggleApp(id: app.id) }
                        ))
                        .toggleStyle(.switch)
                    }
                }
            }
            .frame(height: 200)
            .cornerRadius(8)
        }
    }

    // MARK: - Users Section
    private var usersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Enrolled User Profiles")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button("Add User") {
                    showAddUserSheet = true
                }
            }

            List {
                ForEach(profileManager.profiles) { user in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(user.name)
                                    .font(.system(size: 13, weight: .semibold))
                                if user.id == profileManager.activeUserId {
                                    Text("Active")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                                        .foregroundColor(.blue)
                                }
                            }
                            Text("\(user.templates.count) angle templates enrolled")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if user.id != profileManager.activeUserId {
                            Button("Switch") {
                                profileManager.activeUserId = user.id
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.blue)
                        }

                        if profileManager.profiles.count > 1 {
                            Button(action: { profileManager.removeUser(id: user.id) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(height: 180)
            .cornerRadius(8)
        }
    }

    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Camera Permission", systemImage: "camera.fill")
                Spacer()
                Text("Authorized")
                    .foregroundColor(.green)
                    .font(.system(size: 12.5, weight: .medium))
            }

            HStack {
                Label("Biometric Storage", systemImage: "lock.shield.fill")
                Spacer()
                Text("Encrypted (AES-GCM Keychain)")
                    .foregroundColor(.green)
                    .font(.system(size: 12.5, weight: .medium))
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("On-Device Guarantee")
                    .font(.system(size: 13, weight: .semibold))
                Text("Face ID for Mac operates completely offline. No facial geometry or video frames are ever transmitted over the network or saved as images.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Delete Biometric Data")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)

                Text("Purge all biometric templates, encrypted vault keys, and enrollment data from this Mac.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Button("Delete Face ID Data…", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
    }

    // MARK: - Advanced Section
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Required Consecutive Match Frames: \(matchEngine.settings.requiredConsecutiveFrames)")
                    .font(.system(size: 13, weight: .medium))
                Stepper("", value: $matchEngine.settings.requiredConsecutiveFrames, in: 2...8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Lockout Duration: \(Int(matchEngine.settings.lockoutDuration)) seconds")
                    .font(.system(size: 13, weight: .medium))
            }

            HStack {
                Text("Vision Framework:")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("Apple Vision 2D Landmarks + Pose")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
        }
    }

    private var addUserSheet: some View {
        VStack(spacing: 16) {
            Text("Add Enrolled Profile")
                .font(.system(size: 16, weight: .bold))

            TextField("User Name (e.g. Rahul, Guest)", text: $newUserName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showAddUserSheet = false
                    newUserName = ""
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Profile") {
                    if !newUserName.isEmpty {
                        _ = profileManager.addUser(name: newUserName)
                        showAddUserSheet = false
                        newUserName = ""
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newUserName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360, height: 160)
    }

    private func selectCustomApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            appLocker.addCustomApp(url: url)
        }
    }
}
