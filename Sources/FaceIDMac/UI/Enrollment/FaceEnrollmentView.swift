import SwiftUI
import Vision
import AVFoundation

public struct FaceEnrollmentView: View {
    public var userId: UUID
    public var onComplete: () -> Void
    public var onCancel: () -> Void

    @StateObject private var cameraController = CameraPreviewController()
    @State private var enrollmentStage: Int = 0 // 0 to 5
    @State private var capturedTemplates: [EnrolledTemplate] = []
    @State private var guidanceText: String = "Position your face inside the frame."
    @State private var isCompleted: Bool = false
    @State private var progressAngle: Double = 0
    @State private var isProcessingSample: Bool = false

    @State private var steadyFramesCount: Int = 0
    @State private var currentVector: FaceGeometryVector?

    private let requiredSamples = 5
    private let stageLabels = [
        "Center • Look directly at camera",
        "Left • Turn your head slightly to the left",
        "Right • Turn your head slightly to the right",
        "Up • Tilt your head slightly up",
        "Down • Tilt your head slightly down"
    ]

    public init(userId: UUID, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.userId = userId
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text(isCompleted ? "Face ID Ready" : "Set Up Face ID")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(isCompleted ? "Your face has been securely enrolled on this Mac." : guidanceText)
                    .font(.system(size: 15))
                    .foregroundColor(isCompleted ? .green : .secondary)
                    .animation(.easeInOut(duration: 0.25), value: guidanceText)
            }
            .padding(.top, 24)

            // Scanning Circular Area with Progress Ring
            ZStack {
                // Background Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                isCompleted ? Color.green.opacity(0.15) : Color.blue.opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 170
                        )
                    )
                    .frame(width: 340, height: 340)

                // Outer Track Ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 300, height: 300)

                // Progress Arc
                Circle()
                    .trim(from: 0, to: CGFloat(enrollmentStage) / CGFloat(requiredSamples))
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan, Color.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 300, height: 300)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: enrollmentStage)

                // Camera Preview
                if !isCompleted {
                    CircularCameraPreviewView(controller: cameraController, size: 280)
                } else {
                    // Success Checkmark
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 280, height: 280)

                        Image(systemName: "checkmark")
                            .font(.system(size: 80, weight: .semibold))
                            .foregroundColor(.green)
                            .shadow(color: Color.green.opacity(0.5), radius: 16)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 340, height: 340)

            // Progress Indicators
            if !isCompleted {
                VStack(spacing: 12) {
                    Text("Face Data \(enrollmentStage)/\(requiredSamples)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan)

                    HStack(spacing: 8) {
                        ForEach(0..<requiredSamples, id: \.self) { index in
                            Capsule()
                                .fill(index < enrollmentStage ? Color.green : Color.white.opacity(0.2))
                                .frame(width: 28, height: 4)
                                .animation(.easeInOut, value: enrollmentStage)
                        }
                    }

                    // Manual capture fallback button
                    if currentVector != nil {
                        Button(action: {
                            if let vec = currentVector {
                                captureSample(vector: vec)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.circle.fill")
                                Text("Capture Current Angle")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
            }

            Spacer()

            // Footer Actions
            VStack(spacing: 12) {
                if isCompleted {
                    Button(action: finishEnrollment) {
                        Text("Continue")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 13.5))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 280)
            .padding(.bottom, 28)
        }
        .frame(width: 580, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            startCamera()
        }
        .onDisappear {
            CameraManager.shared.stopCapture()
        }
    }

    private func startCamera() {
        CameraManager.shared.startCapture()

        cameraController.onFrameAnalyzed = { analysis, sampleBuffer in
            guard !self.isCompleted, !self.isProcessingSample else { return }

            if analysis.faceCount == 0 {
                self.guidanceText = "Position your face inside the frame."
                self.currentVector = nil
                self.steadyFramesCount = 0
                return
            }

            if analysis.faceCount > 1 {
                self.guidanceText = "Only one person should be in view."
                self.currentVector = nil
                self.steadyFramesCount = 0
                return
            }

            guard let vector = analysis.vector else {
                self.guidanceText = analysis.guidance
                self.currentVector = nil
                self.steadyFramesCount = 0
                return
            }

            self.currentVector = vector

            // Verify angle requirements for current stage
            self.verifyAndCaptureSample(vector: vector, observation: analysis.observation)
        }
    }

    private func verifyAndCaptureSample(vector: FaceGeometryVector, observation: VNFaceObservation?) {
        guard let obs = observation else { return }
        let yaw = obs.yaw?.floatValue ?? 0
        let pitch = obs.pitch?.floatValue ?? 0

        // Calculate robust geometric ratios from landmarks
        var verticalRatio: Float = 1.0
        var horizontalRatio: Float = 1.0

        if let landmarks = obs.landmarks,
           let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye,
           let nose = landmarks.nose,
           let outerLips = landmarks.outerLips {

            func centroid(_ points: [CGPoint]) -> CGPoint {
                guard !points.isEmpty else { return .zero }
                let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
                return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
            }

            func dist(_ p1: CGPoint, _ p2: CGPoint) -> Float {
                let dx = Float(p1.x - p2.x)
                let dy = Float(p1.y - p2.y)
                return sqrt(dx * dx + dy * dy)
            }

            let leftEyeCenter = centroid(leftEye.normalizedPoints)
            let rightEyeCenter = centroid(rightEye.normalizedPoints)
            let eyeCenter = CGPoint(x: (leftEyeCenter.x + rightEyeCenter.x) / 2, y: (leftEyeCenter.y + rightEyeCenter.y) / 2)
            let noseCenter = centroid(nose.normalizedPoints)
            let mouthCenter = centroid(outerLips.normalizedPoints)

            let eyeToNose = dist(eyeCenter, noseCenter)
            let noseToMouth = dist(noseCenter, mouthCenter)
            if noseToMouth > 0.001 {
                verticalRatio = eyeToNose / noseToMouth
            }

            let leftEyeToNose = dist(leftEyeCenter, noseCenter)
            let rightEyeToNose = dist(rightEyeCenter, noseCenter)
            if rightEyeToNose > 0.001 {
                horizontalRatio = leftEyeToNose / rightEyeToNose
            }
        }

        var isAngleValid = false
        var nextInstruction = ""

        switch enrollmentStage {
        case 0: // Center
            if abs(yaw) < 0.15 {
                isAngleValid = true
                nextInstruction = "Now turn your head slightly to the left"
            } else {
                guidanceText = "Look directly at the camera"
            }

        case 1: // Left
            if yaw < -0.06 || horizontalRatio < 0.88 {
                isAngleValid = true
                nextInstruction = "Now turn your head slightly to the right"
            } else {
                guidanceText = "Turn head slightly to the left"
            }

        case 2: // Right
            if yaw > 0.06 || horizontalRatio > 1.14 {
                isAngleValid = true
                nextInstruction = "Now tilt your head slightly up"
            } else {
                guidanceText = "Turn head slightly to the right"
            }

        case 3: // Up
            // Tilting up: eyes move closer to nose, verticalRatio drops, or pitch > 0.03
            if verticalRatio < 0.98 || pitch > 0.03 {
                isAngleValid = true
                nextInstruction = "Now tilt your head slightly down"
            } else {
                guidanceText = "Tilt head slightly up"
            }

        case 4: // Down
            // Tilting down: nose moves closer to mouth, verticalRatio increases, or pitch < -0.03
            if verticalRatio > 1.20 || pitch < -0.03 {
                isAngleValid = true
            } else {
                guidanceText = "Tilt head slightly down"
            }

        default:
            break
        }

        // Auto-capture steady fallback
        steadyFramesCount += 1
        if steadyFramesCount > 35 { // ~1.2 seconds of steady frame
            isAngleValid = true
            steadyFramesCount = 0
        }

        if isAngleValid {
            captureSample(vector: vector, nextInstruction: nextInstruction)
        }
    }

    private func captureSample(vector: FaceGeometryVector, nextInstruction: String = "") {
        guard !isProcessingSample, !isCompleted else { return }
        isProcessingSample = true
        steadyFramesCount = 0

        let template = EnrolledTemplate(
            label: "Angle \(enrollmentStage + 1)",
            vector: vector
        )
        capturedTemplates.append(template)
        AudioFeedback.shared.playScanStart()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.enrollmentStage += 1
            if self.enrollmentStage >= self.requiredSamples {
                self.isCompleted = true
                AudioFeedback.shared.playRecognized()
                CameraManager.shared.stopCapture()
            } else {
                if !nextInstruction.isEmpty {
                    self.guidanceText = nextInstruction
                } else if self.enrollmentStage < self.stageLabels.count {
                    self.guidanceText = self.stageLabels[self.enrollmentStage]
                }
            }
            self.isProcessingSample = false
        }
    }

    private func finishEnrollment() {
        ProfileManager.shared.saveTemplates(for: userId, templates: capturedTemplates)
        // Ensure Launch at Login is permanently enabled
        LaunchAtLoginManager.shared.setEnabled(true)
        AutoLockManager.shared.isAutoLockEnabled = true
        onComplete()
    }
}
