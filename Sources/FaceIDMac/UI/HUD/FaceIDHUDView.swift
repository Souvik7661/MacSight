import SwiftUI
import Combine

public struct FaceIDHUDView: View {
    @ObservedObject public var matchEngine = BiometricMatchEngine.shared
    @ObservedObject public var profileManager = ProfileManager.shared
    @StateObject private var cameraController = CameraPreviewController()

    public var targetAppName: String? = nil
    public var onAuthenticated: ((UserProfile) -> Void)?
    public var onDismiss: (() -> Void)?

    @State private var lottieState: FaceIDVisualState = .searching
    @State private var statusTitle: String = "Face ID"
    @State private var statusSubtitle: String = "Looking for you…"
    @State private var isSuccess: Bool = false
    @State private var isScanning: Bool = false
    @State private var showCameraPip: Bool = false

    public init(
        targetAppName: String? = nil,
        onAuthenticated: ((UserProfile) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.targetAppName = targetAppName
        self.onAuthenticated = onAuthenticated
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Frosted Glass Apple Backdrop
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header Bar with target app if applicable
                HStack {
                    if let appName = targetAppName {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Unlocking \(appName)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }

                    Spacer()

                    // Toggle mini camera PiP preview button
                    Button(action: { showCameraPip.toggle() }) {
                        Image(systemName: showCameraPip ? "video.fill" : "video.slash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Camera Preview")

                    if let dismiss = onDismiss {
                        Button(action: dismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(6)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                Spacer()

                // Face ID Lottie Animation + Ambient Glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    isSuccess ? Color.green.opacity(0.25) : Color.blue.opacity(0.18),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(isScanning ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isScanning)

                    FaceIDLottieView(
                        state: $lottieState,
                        onComplete: { completedState in
                            if completedState == .success {
                                // Handled in state change
                            }
                        }
                    )
                    .frame(width: 150, height: 150)
                }

                // Mini Camera Preview (optional overlay)
                if showCameraPip {
                    CircularCameraPreviewView(controller: cameraController, size: 100, showLandmarks: false, showBrackets: true)
                        .padding(.top, -10)
                        .padding(.bottom, 6)
                        .transition(.scale.combined(with: .opacity))
                }

                // Status Typography
                VStack(spacing: 5) {
                    Text(statusTitle)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(isSuccess ? .green : .white)

                    Text(statusSubtitle)
                        .font(.system(size: 13.5))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .padding(.top, 16)

                Spacer()

                // Fallback Authentication Actions
                VStack(spacing: 12) {
                    if matchEngine.isLockedOut {
                        Text("Locked out. Retry in \(Int(matchEngine.lockoutTimeRemaining))s")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                    }

                    Button(action: authenticateWithPassword) {
                        HStack(spacing: 6) {
                            Image(systemName: "touchid")
                            Text("Use Touch ID or Password")
                        }
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 22)
            }
        }
        .frame(width: 380, height: 420)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 32, x: 0, y: 16)
        .onAppear {
            startRecognition()
        }
        .onDisappear {
            stopRecognition()
        }
    }

    private func startRecognition() {
        matchEngine.resetSession()
        CameraManager.shared.startCapture()
        isScanning = true
        lottieState = .searching

        cameraController.onFrameAnalyzed = { analysis, sampleBuffer in
            guard !self.isSuccess else { return }

            let result = self.matchEngine.evaluateFrame(
                analysis: analysis,
                profiles: self.profileManager.profiles
            )

            self.handleMatchResult(result)
        }
    }

    private func stopRecognition() {
        CameraManager.shared.stopCapture()
        isScanning = false
    }

    private func handleMatchResult(_ result: MatchResult) {
        switch result {
        case .noFace:
            self.statusTitle = "Face ID"
            self.statusSubtitle = "Looking for you…"
            if lottieState != .searching { lottieState = .searching }

        case .analyzing(let guidance):
            self.statusTitle = "Face ID"
            self.statusSubtitle = guidance
            if lottieState != .scanning { lottieState = .scanning }

        case .livenessRequired(let hint):
            self.statusTitle = "Face ID"
            self.statusSubtitle = hint
            if lottieState != .scanning { lottieState = .scanning }

        case .authenticated(let user, _):
            self.isSuccess = true
            self.lottieState = .success
            self.statusTitle = "Face Recognized"
            self.statusSubtitle = "Welcome back, \(user.name)."
            AudioFeedback.shared.playRecognized()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                self.stopRecognition()
                self.onAuthenticated?(user)
            }

        case .notRecognized:
            self.statusTitle = "Face Not Recognized"
            self.statusSubtitle = "Try again."
            self.lottieState = .failure
            AudioFeedback.shared.playFailure()
            self.matchEngine.registerExplicitFailure()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if !self.isSuccess {
                    self.statusTitle = "Face ID"
                    self.statusSubtitle = "Looking for you…"
                    self.lottieState = .searching
                }
            }

        case .lockedOut:
            self.statusTitle = "Temporary Lockout"
            self.statusSubtitle = "Too many failed attempts."
            self.lottieState = .failure
        }
    }

    private func authenticateWithPassword() {
        matchEngine.authenticateWithSystem { success in
            if success, let user = profileManager.activeUser {
                self.isSuccess = true
                self.lottieState = .success
                self.statusTitle = "Authenticated"
                self.statusSubtitle = "Welcome back, \(user.name)."
                AudioFeedback.shared.playRecognized()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.stopRecognition()
                    self.onAuthenticated?(user)
                }
            }
        }
    }
}

// MARK: - AppKit Visual Effect Blur View for Native macOS Glass
public struct VisualEffectView: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public init(material: NSVisualEffectView.Material = .hudWindow, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
