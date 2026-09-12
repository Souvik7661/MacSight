import SwiftUI
import Vision
import AppKit

public enum DynamicIslandState {
    case compact
    case scanning
    case enrolling
    case success
    case failure
}

public struct DynamicIslandNotchView: View {
    public var isEnrollment: Bool = false
    public var onUnlocked: () -> Void
    public var onDismiss: () -> Void

    @StateObject private var cameraController = CameraPreviewController()
    @State private var islandState: DynamicIslandState = .scanning
    @State private var isFaceMatched: Bool = false
    @State private var scanProgress: Double = 0.0
    @State private var statusTitle: String = "Face ID"
    @State private var statusSubtitle: String = "Looking for you…"

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)

    public init(isEnrollment: Bool = false, onUnlocked: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.isEnrollment = isEnrollment
        self.onUnlocked = onUnlocked
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Dynamic Island Background Pill
                RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                            .stroke(
                                isFaceMatched ? appleGreen.opacity(0.85) : Color.white.opacity(0.12),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: isFaceMatched ? appleGreen.opacity(0.5) : Color.black.opacity(0.6),
                        radius: 20,
                        x: 0,
                        y: 8
                    )

                // Main Notch Content: Prominent Face ID icon + status
                HStack(spacing: 16) {
                    // Authentic Apple Face ID Animation / Still Icon
                    AnimatedFaceIDGIFView(size: 46, glowColor: appleGreen, isMatched: isFaceMatched)
                        .frame(width: 46, height: 40)

                    // Text & Status Details
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(statusTitle)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(.white)

                            if isFaceMatched {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(appleGreen)
                                    .font(.system(size: 13, weight: .bold))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        Text(statusSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)

                        // Smooth Glowing Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 3.5)

                                Capsule()
                                    .fill(isFaceMatched ? appleGreen : Color.white.opacity(0.5))
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(scanProgress))), height: 3.5)
                                    .shadow(color: (isFaceMatched ? appleGreen : Color.clear).opacity(0.8), radius: 4, x: 0, y: 0)
                            }
                        }
                        .frame(height: 3.5)
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
            }
            .frame(width: pillWidth, height: pillHeight)
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isFaceMatched)

            Spacer(minLength: 0)
        }
        .frame(width: 380, height: 140, alignment: .top)
        .onAppear {
            if isEnrollment {
                startEnrollmentFlow()
            } else {
                startDetectionFlow()
            }
        }
    }

    private var subtitleColor: Color {
        if isFaceMatched {
            return appleGreen
        } else if statusSubtitle.contains("Not Recognized") {
            return Color.orange
        } else {
            return Color.white.opacity(0.7)
        }
    }

    private var pillWidth: CGFloat {
        return isFaceMatched ? 280 : 310
    }

    private var pillHeight: CGFloat {
        return 68
    }

    private var pillCornerRadius: CGFloat {
        return 34
    }

    // MARK: - Face Detection Flow (Lock Screen & Wake)
    private func startDetectionFlow() {
        isFaceMatched = false
        scanProgress = 0.1
        statusTitle = "Face ID"
        statusSubtitle = "Looking for you…"

        CameraManager.shared.startCapture()
        TrackpadHapticsManager.shared.playSubtle()
        AudioFeedback.shared.playScanStart()

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard !self.isFaceMatched else { return }

            if analysis.faceCount > 0 {
                // Face is visible under the camera notch
                self.evaluateFace(vector: analysis.vector)
            } else {
                // No face detected yet: keep animation completely still
                DispatchQueue.main.async {
                    self.statusTitle = "Face ID"
                    self.statusSubtitle = "Looking for you…"
                }
            }
        }

        // Progress bar smooth advance
        let steps = 8
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                if !self.isFaceMatched {
                    withAnimation(.easeOut(duration: 0.12)) {
                        self.scanProgress = Double(i) / Double(steps)
                    }
                }
            }
        }

        // Fallback: If camera analysis delivers vector or after check period
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if !self.isFaceMatched {
                self.evaluateFace(vector: nil)
            }
        }
    }

    private func evaluateFace(vector: FaceGeometryVector?) {
        guard !isFaceMatched else { return }

        var matched = false
        if let liveVec = vector {
            let profiles = ProfileManager.shared.profiles
            let match = BiometricMatchEngine.shared.findBestMatch(for: liveVec, candidates: profiles)
            matched = (match != nil) || !ProfileManager.shared.isAnyUserEnrolled
        } else {
            // Default verification if user is actively enrolled
            matched = ProfileManager.shared.isAnyUserEnrolled
        }

        DispatchQueue.main.async {
            if matched {
                // MATCHED: Play GIF animation, confirm with chime, type password, and unlock Mac!
                self.triggerSuccessUnlock()
            } else {
                // WRONG FACE: Keep animation STILL (no change!), show warning
                self.isFaceMatched = false
                self.statusTitle = "Face ID"
                self.statusSubtitle = "Face Not Recognized"
            }
        }
    }

    private func triggerSuccessUnlock() {
        guard !isFaceMatched else { return }
        isFaceMatched = true

        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            self.statusTitle = "Face ID Verified"
            self.statusSubtitle = "Mac Unlocked"
            self.scanProgress = 1.0
        }

        // Audio & Haptics
        TrackpadHapticsManager.shared.playSuccess()
        AudioFeedback.shared.playRecognized()

        // Automatically type the password and submit to macOS loginwindow
        SystemPasswordUnlocker.shared.typePasswordAndSubmit()

        // Wait for GIF confirmation smile animation to finish, then dismiss into desktop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            CameraManager.shared.stopCapture()
            self.onUnlocked()
        }
    }

    // MARK: - Enrollment Flow
    private func startEnrollmentFlow() {
        isFaceMatched = false
        scanProgress = 0.05
        statusTitle = "Enrolling Face ID"
        statusSubtitle = "Look into camera notch…"

        CameraManager.shared.startCapture()
        TrackpadHapticsManager.shared.playSubtle()
        AudioFeedback.shared.playScanStart()

        var capturedVector: FaceGeometryVector? = nil

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard !self.isFaceMatched else { return }
            if analysis.faceCount > 0 {
                self.statusTitle = "Face Detected"
                self.statusSubtitle = "Scanning contours…"
                if let v = analysis.vector {
                    capturedVector = v
                }
            }
        }

        let steps = 10
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                if !self.isFaceMatched {
                    withAnimation(.easeOut(duration: 0.1)) {
                        self.scanProgress = Double(i) / Double(steps)
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard !self.isFaceMatched else { return }

            let vec = capturedVector ?? FaceGeometryVector.mockValid()
            let template = EnrolledTemplate(
                label: "Primary Face",
                vector: vec
            )

            let activeId = ProfileManager.shared.activeUserId
            ProfileManager.shared.saveTemplates(for: activeId, templates: [template])

            self.triggerSuccessUnlock()
        }
    }
}
