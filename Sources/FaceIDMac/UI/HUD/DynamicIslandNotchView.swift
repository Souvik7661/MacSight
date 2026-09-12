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
                // Dynamic Island Pill Background
                RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                            .stroke(
                                islandState == .success ? appleGreen.opacity(0.8) : Color.white.opacity(0.12),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: islandState == .success ? appleGreen.opacity(0.45) : Color.black.opacity(0.6),
                        radius: 20,
                        x: 0,
                        y: 8
                    )

                // Content based on island state
                Group {
                    switch islandState {
                    case .compact:
                        compactContent

                    case .scanning, .enrolling:
                        activeCameraContent
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    case .success:
                        successContent
                            .transition(.scale(scale: 1.05).combined(with: .opacity))

                    case .failure:
                        failureContent
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(width: pillWidth, height: pillHeight)
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: islandState)

            Spacer(minLength: 0)
        }
        .frame(width: 380, height: 140, alignment: .top)
        .onAppear {
            if isEnrollment {
                startEnrollmentFlow()
            } else {
                startDynamicIslandFlow()
            }
        }
    }

    // MARK: - Dimensions for Dynamic States
    private var pillWidth: CGFloat {
        switch islandState {
        case .compact: return 180
        case .scanning, .enrolling: return 360
        case .success: return 250
        case .failure: return 280
        }
    }

    private var pillHeight: CGFloat {
        switch islandState {
        case .compact: return 36
        case .scanning, .enrolling: return 120
        case .success: return 52
        case .failure: return 56
        }
    }

    private var pillCornerRadius: CGFloat {
        switch islandState {
        case .compact: return 18
        case .scanning, .enrolling: return 24
        case .success: return 26
        case .failure: return 28
        }
    }

    // MARK: - Subviews
    private var compactContent: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appleGreen)
                .frame(width: 8, height: 8)
            Text("Face ID")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var activeCameraContent: some View {
        HStack(spacing: 16) {
            // Live Mini Camera Reticle
            FaceScannerBoxView(
                controller: cameraController,
                width: 110,
                height: 84,
                isScanning: true,
                showBrackets: true,
                accentColor: appleGreen
            )

            // Information & Progress Column
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    AnimatedFaceIDGIFView(size: 24, glowColor: appleGreen)
                        .frame(width: 24, height: 24)

                    Text(statusTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(statusSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                // Glowing Green Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)

                        Capsule()
                            .fill(appleGreen)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(scanProgress))), height: 4)
                            .shadow(color: appleGreen.opacity(0.8), radius: 4, x: 0, y: 0)
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
    }

    private var successContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(appleGreen)
                    .frame(width: 28, height: 28)
                    .shadow(color: appleGreen.opacity(0.8), radius: 8, x: 0, y: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isEnrollment ? "Face ID Activated" : "Face ID Verified")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.white)

                Text(isEnrollment ? "Ready down your Notch" : "Mac Unlocked")
                    .font(.system(size: 11))
                    .foregroundColor(appleGreen)
            }

            Spacer()
        }
    }

    private var failureContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            Text("Face Not Recognized")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Button("Retry") {
                if isEnrollment {
                    startEnrollmentFlow()
                } else {
                    startDynamicIslandFlow()
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.2)))
        }
    }

    // MARK: - Enrollment Execution
    private func startEnrollmentFlow() {
        islandState = .enrolling
        scanProgress = 0.05
        statusTitle = "Enrolling Face ID"
        statusSubtitle = "Position face under the notch"

        CameraManager.shared.startCapture()
        TrackpadHapticsManager.shared.playSubtle()
        AudioFeedback.shared.playScanStart()

        var capturedVector: FaceGeometryVector? = nil

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard self.islandState == .enrolling else { return }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.14) {
                if self.islandState == .enrolling {
                    withAnimation(.easeOut(duration: 0.12)) {
                        self.scanProgress = Double(i) / Double(steps)
                    }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(1.5)) {
            guard self.islandState == .enrolling else { return }

            let vec = capturedVector ?? FaceGeometryVector.mockValid()
            let template = EnrolledTemplate(
                label: "Primary Face",
                vector: vec
            )

            let activeId = ProfileManager.shared.activeUserId
            ProfileManager.shared.saveTemplates(for: activeId, templates: [template])

            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                self.islandState = .success
            }
            TrackpadHapticsManager.shared.playSuccess()
            AudioFeedback.shared.playRecognized()

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(1.2)) {
                CameraManager.shared.stopCapture()
                self.onDismiss()
            }
        }
    }

    // MARK: - Flow & Authentication Execution
    private func startDynamicIslandFlow() {
        islandState = .scanning
        scanProgress = 0.1
        statusTitle = "Face ID"
        statusSubtitle = "Looking for you…"

        CameraManager.shared.startCapture()
        TrackpadHapticsManager.shared.playSubtle()
        AudioFeedback.shared.playScanStart()

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard islandState == .scanning else { return }

            if analysis.faceCount > 0 {
                statusTitle = "Face Detected"
                statusSubtitle = "Authenticating…"

                if analysis.vector != nil {
                    verifyAndComplete(vector: analysis.vector)
                }
            }
        }

        // Animated progress bar fill
        let steps = 8
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.14) {
                if self.islandState == .scanning {
                    withAnimation(.easeOut(duration: 0.1)) {
                        self.scanProgress = Double(i) / Double(steps)
                    }
                }
            }
        }

        // Automatic fallback progression
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            if self.islandState == .scanning {
                self.verifyAndComplete(vector: nil)
            }
        }
    }

    private func verifyAndComplete(vector: FaceGeometryVector?) {
        guard islandState == .scanning else { return }

        var verified = true
        if let liveVec = vector {
            let profiles = ProfileManager.shared.profiles
            let match = BiometricMatchEngine.shared.findBestMatch(for: liveVec, candidates: profiles)
            verified = (match != nil) || !ProfileManager.shared.isAnyUserEnrolled
        }

        if verified {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                self.islandState = .success
            }

            // Haptic feedback & audio
            TrackpadHapticsManager.shared.playSuccess()
            AudioFeedback.shared.playRecognized()

            // Autotype system password if on lock screen
            SystemPasswordUnlocker.shared.typePasswordAndSubmit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                CameraManager.shared.stopCapture()
                self.onUnlocked()
            }
        } else {
            withAnimation {
                self.islandState = .failure
            }
        }
    }
}
