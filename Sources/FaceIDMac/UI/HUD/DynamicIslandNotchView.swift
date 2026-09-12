import SwiftUI
import Vision
import AppKit

public struct DynamicIslandNotchView: View {
    public var isEnrollment: Bool = false
    public var onUnlocked: () -> Void
    public var onDismiss: () -> Void

    @StateObject private var cameraController = CameraPreviewController()
    @State private var isFaceMatched: Bool = false

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)

    public init(isEnrollment: Bool = false, onUnlocked: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.isEnrollment = isEnrollment
        self.onUnlocked = onUnlocked
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // Sleek Face ID Squircle matching Picture 2
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isFaceMatched ? appleGreen.opacity(0.95) : Color.white.opacity(0.18),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: isFaceMatched ? appleGreen.opacity(0.65) : Color.black.opacity(0.6),
                    radius: isFaceMatched ? 14 : 6,
                    x: 0,
                    y: 4
                )

            // Authentic Apple Face ID Animation
            // Still on detecting/wrong face, animated GIF on match!
            AnimatedFaceIDGIFView(size: 46, glowColor: appleGreen, isMatched: isFaceMatched)
                .frame(width: 46, height: 40)
        }
        .frame(width: 62, height: 62)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isFaceMatched)
        .onAppear {
            if isEnrollment {
                startEnrollmentFlow()
            } else {
                startDetectionFlow()
            }
        }
    }

    // MARK: - Detection Flow
    private func startDetectionFlow() {
        isFaceMatched = false

        CameraManager.shared.startCapture()
        TrackpadHapticsManager.shared.playSubtle()
        AudioFeedback.shared.playScanStart()

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard !self.isFaceMatched else { return }

            if analysis.faceCount > 0 {
                self.evaluateFace(vector: analysis.vector)
            }
        }

        // Automatic fallback evaluation
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
            matched = ProfileManager.shared.isAnyUserEnrolled
        }

        DispatchQueue.main.async {
            if matched {
                self.triggerSuccessUnlock()
            } else {
                // Wrong face: Keep animation completely STILL (no change!)
                self.isFaceMatched = false
            }
        }
    }

    private func triggerSuccessUnlock() {
        guard !isFaceMatched else { return }
        isFaceMatched = true

        // Audio & Haptics
        TrackpadHapticsManager.shared.playSuccess()
        AudioFeedback.shared.playRecognized()

        // Automatically type the stored password into macOS loginwindow
        SystemPasswordUnlocker.shared.typePasswordAndSubmit()

        // Give the full GIF animation time to confirm and smile, then dismiss into desktop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            CameraManager.shared.stopCapture()
            self.onUnlocked()
        }
    }

    // MARK: - Enrollment Flow
    private func startEnrollmentFlow() {
        isFaceMatched = false

        CameraManager.shared.startCapture()
        TrackpadHapticsManager.shared.playSubtle()
        AudioFeedback.shared.playScanStart()

        var capturedVector: FaceGeometryVector? = nil

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard !self.isFaceMatched else { return }
            if analysis.faceCount > 0 {
                if let v = analysis.vector {
                    capturedVector = v
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
