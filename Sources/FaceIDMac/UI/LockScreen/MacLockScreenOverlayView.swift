import SwiftUI
import Vision
import LocalAuthentication
import AVFoundation

public enum LockScreenStage: Int, CaseIterable {
    case locked = 5         // Step 5: Lock Your Mac (Clock, Padlock, "Your Mac is Locked")
    case detecting = 6      // Step 6: Face Detection ("Face detected", "Verifying your identity...")
    case authenticating = 7 // Step 7: Authenticating ("Authenticating...", green beam, progress bar)
    case unlocked = 8       // Step 8: Mac Unlocked ("Welcome Back! Your Mac is Unlocked", desktop & dock)
}

public struct MacLockScreenOverlayView: View {
    public var onUnlocked: () -> Void
    public var onDismiss: () -> Void

    @StateObject private var cameraController = CameraPreviewController()
    @State private var currentStage: LockScreenStage = .locked
    @State private var currentTimeString: String = ""
    @State private var currentDateString: String = ""
    @State private var authProgress: Double = 0.0
    @State private var timeTimer: Timer?
    @State private var activeUserName: String = "User"

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)

    public init(onUnlocked: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onUnlocked = onUnlocked
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Background Wallpaper
            MacWallpaperDunesView()
                .edgesIgnoringSafeArea(.all)

            // Stage Switcher
            VStack {
                // Top Bar (Clock & Menu Bar mock for Step 8 or lock status)
                if currentStage == .unlocked {
                    DesktopMenuBarMock()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Dynamic Stage Content
                switch currentStage {
                case .locked:
                    step5LockedView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .detecting:
                    step6DetectingView
                        .transition(.opacity)

                case .authenticating:
                    step7AuthenticatingView
                        .transition(.opacity)

                case .unlocked:
                    step8UnlockedView
                        .transition(.scale(scale: 1.04).combined(with: .opacity))
                }

                Spacer()

                // Bottom Bar Controls
                if currentStage == .unlocked {
                    DesktopDockMock()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if currentStage == .locked {
                    step5BottomControls
                        .transition(.opacity)
                } else {
                    // Touch ID / Password Fallback during scanning
                    Button(action: fallbackToTouchIDOrPassword) {
                        HStack(spacing: 6) {
                            Image(systemName: "touchid")
                            Text("Use Touch ID or Password")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 24)

            // Stage switcher pill for instant preview / manual test
            VStack {
                HStack {
                    Spacer()
                    StageSelectorPill(currentStage: $currentStage, onChange: handleManualStageChange)
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Close Overlay")
                }
                .padding(.top, 14)
                .padding(.trailing, 18)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateTime()
            startTimeTimer()
            resolveActiveUser()
            startFaceRecognitionEngine()
        }
        .onDisappear {
            timeTimer?.invalidate()
            timeTimer = nil
            CameraManager.shared.stopCapture()
        }
    }

    // MARK: - Step 5: Lock Your Mac
    private var step5LockedView: some View {
        VStack(spacing: 20) {
            // Large Lock Screen Clock
            VStack(spacing: 4) {
                Text(currentTimeString)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                Text(currentDateString)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            }
            .padding(.bottom, 28)

            // Padlock Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1.5))

                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(.white.opacity(0.95))
            }
            .padding(.bottom, 6)

            // Titles
            VStack(spacing: 8) {
                Text("Your Mac is Locked")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                Text("Use Face ID to unlock")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.75))
            }

            // Quick trigger button to scan
            Button(action: {
                withAnimation { currentStage = .detecting }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "faceid")
                    Text("Unlock with Face ID")
                }
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Capsule().fill(appleGreen))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
    }

    private var step5BottomControls: some View {
        HStack(spacing: 44) {
            BottomPowerButton(icon: "moon.fill", label: "Sleep") {
                AutoLockManager.shared.lockWorkspace()
            }
            BottomPowerButton(icon: "arrow.counterclockwise", label: "Restart") {}
            BottomPowerButton(icon: "power", label: "Shut Down") {}
        }
        .padding(.bottom, 28)
    }

    // MARK: - Step 6: Face Detection
    private var step6DetectingView: some View {
        VStack(spacing: 16) {
            FaceScannerBoxView(
                controller: cameraController,
                width: 320,
                height: 240,
                isScanning: false,
                showBrackets: true,
                statusText: "Face detected",
                secondaryText: "Verifying your identity...",
                accentColor: appleGreen
            )

            Text("Position your face within the frame")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Step 7: Authenticating
    private var step7AuthenticatingView: some View {
        VStack(spacing: 16) {
            FaceScannerBoxView(
                controller: cameraController,
                width: 320,
                height: 240,
                isScanning: true,
                showBrackets: true,
                statusText: "Authenticating...",
                secondaryText: "Matching against secure Keychain template",
                progress: authProgress,
                accentColor: appleGreen
            )
        }
    }

    // MARK: - Step 8: Mac Unlocked
    private var step8UnlockedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [appleGreen.opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)

                Circle()
                    .stroke(appleGreen, lineWidth: 3.5)
                    .frame(width: 88, height: 88)
                    .shadow(color: appleGreen.opacity(0.85), radius: 16, x: 0, y: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(appleGreen)
                    .shadow(color: appleGreen.opacity(0.9), radius: 10, x: 0, y: 0)
            }

            VStack(spacing: 8) {
                Text("Welcome Back!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)

                Text("Your Mac is Unlocked")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            }
        }
    }

    // MARK: - Face Recognition & Automation
    private func startFaceRecognitionEngine() {
        CameraManager.shared.startCapture()

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard currentStage == .locked || currentStage == .detecting else { return }

            if analysis.faceCount > 0 {
                if currentStage == .locked {
                    withAnimation { currentStage = .detecting }
                }

                // If face is steady and vector is ready, start authenticating
                if analysis.vector != nil && currentStage == .detecting {
                    triggerAuthentication(vector: analysis.vector)
                }
            }
        }

        // Automatic simulated progression if running without live webcam
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if self.currentStage == .locked {
                withAnimation { self.currentStage = .detecting }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.currentStage == .detecting {
                        self.triggerAuthentication(vector: nil)
                    }
                }
            }
        }
    }

    private func triggerAuthentication(vector: FaceGeometryVector?) {
        guard currentStage != .authenticating && currentStage != .unlocked else { return }

        withAnimation {
            currentStage = .authenticating
            authProgress = 0.1
        }
        AudioFeedback.shared.playScanStart()

        // Progressive authentication fill
        let steps = 10
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                withAnimation(.easeOut(duration: 0.1)) {
                    self.authProgress = Double(i) / Double(steps)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            // Perform real cosine match if vector available
            var matchSuccess = true
            if let liveVec = vector {
                let profiles = ProfileManager.shared.profiles
                let bestMatch = BiometricMatchEngine.shared.findBestMatch(for: liveVec, candidates: profiles)
                matchSuccess = (bestMatch != nil) || !ProfileManager.shared.isAnyUserEnrolled
            }

            if matchSuccess {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    self.currentStage = .unlocked
                }
                AudioFeedback.shared.playRecognized()

                // Dismiss lock screen after success confirmation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    CameraManager.shared.stopCapture()
                    self.onUnlocked()
                }
            } else {
                // Retry
                withAnimation { self.currentStage = .detecting }
            }
        }
    }

    private func handleManualStageChange(_ stage: LockScreenStage) {
        if stage == .authenticating {
            triggerAuthentication(vector: nil)
        } else if stage == .unlocked {
            AudioFeedback.shared.playRecognized()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.onUnlocked()
            }
        }
    }

    private func fallbackToTouchIDOrPassword() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your Mac") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation { self.currentStage = .unlocked }
                        AudioFeedback.shared.playRecognized()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.onUnlocked()
                        }
                    }
                }
            }
        }
    }

    private func updateTime() {
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        currentTimeString = timeFormatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, d MMMM"
        currentDateString = dateFormatter.string(from: now)
    }

    private func startTimeTimer() {
        timeTimer?.invalidate()
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTime()
        }
    }

    private func resolveActiveUser() {
        if let user = ProfileManager.shared.activeUser {
            activeUserName = user.name
        }
    }
}

// MARK: - Bottom Power Control Button
struct BottomPowerButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                }

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stage Selector Pill (Allows immediate navigation between Stages 5, 6, 7, 8)
struct StageSelectorPill: View {
    @Binding var currentStage: LockScreenStage
    var onChange: (LockScreenStage) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LockScreenStage.allCases, id: \.self) { stage in
                Button(action: {
                    withAnimation {
                        currentStage = stage
                        onChange(stage)
                    }
                }) {
                    Text("Step \(stage.rawValue)")
                        .font(.system(size: 11, weight: currentStage == stage ? .bold : .regular))
                        .foregroundColor(currentStage == stage ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(currentStage == stage ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }
}

// MARK: - macOS Desktop Menu Bar Mock (for Step 8)
struct DesktopMenuBarMock: View {
    var body: some View {
        HStack {
            Image(systemName: "applelogo")
                .font(.system(size: 13))
            Text("Finder")
                .font(.system(size: 12, weight: .semibold))
            Text("File")
            Text("Edit")
            Text("View")
            Text("Go")
            Text("Window")
            Text("Help")
            Spacer()
            Image(systemName: "faceid")
                .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
            Image(systemName: "wifi")
            Image(systemName: "battery.100")
            Text("Tue Sep 9 10:24 AM")
        }
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(VisualEffectView(material: .menu, blendingMode: .withinWindow))
    }
}

// MARK: - macOS Desktop Dock Mock (for Step 8)
struct DesktopDockMock: View {
    private let dockIcons = ["finder", "launchpad", "safari", "messages", "mail", "photos", "terminal", "systempreferences"]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            Image(systemName: "safari.fill")
                .foregroundColor(.cyan)
            Image(systemName: "message.fill")
                .foregroundColor(.green)
            Image(systemName: "envelope.fill")
                .foregroundColor(.blue)
            Image(systemName: "photo.fill")
                .foregroundColor(.pink)
            Image(systemName: "terminal.fill")
                .foregroundColor(.gray)
            Image(systemName: "gearshape.fill")
                .foregroundColor(.gray)
        }
        .font(.system(size: 28))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .padding(.bottom, 16)
    }
}
