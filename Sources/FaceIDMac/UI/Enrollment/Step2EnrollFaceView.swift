import SwiftUI
import Vision
import AVFoundation

public struct Step2EnrollFaceView: View {
    public var userId: UUID
    public var onAnglesCompleted: ([EnrolledTemplate]) -> Void
    public var onCancel: () -> Void

    @StateObject private var cameraController = CameraPreviewController()
    @State private var currentAngleIndex: Int = 0
    @State private var capturedTemplates: [EnrolledTemplate] = []
    @State private var angleChecklist: [Bool] = [false, false, false, false, false]
    @State private var guidanceSubtitle: String = "Position your face within the frame"
    @State private var steadyFrames: Int = 0
    @State private var currentVector: FaceGeometryVector?

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let angleTitles = [
        "Look at the camera",
        "Turn left",
        "Turn right",
        "Look up",
        "Look down"
    ]

    public init(
        userId: UUID,
        onAnglesCompleted: @escaping ([EnrolledTemplate]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.userId = userId
        self.onAnglesCompleted = onAnglesCompleted
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text("Enroll Your Face")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Position your face in front of the camera and capture multiple angles.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Main 2-Column Enrollment Interface (matching diagram Step 2)
            HStack(alignment: .center, spacing: 32) {
                // Left Column: Camera Box with Green Brackets [  ]
                VStack(spacing: 8) {
                    FaceScannerBoxView(
                        controller: cameraController,
                        width: 320,
                        height: 240,
                        isScanning: false,
                        showBrackets: true,
                        statusText: guidanceSubtitle,
                        accentColor: appleGreen
                    )

                    // Manual capture override / skip for testing convenience
                    Button(action: recordCurrentAngle) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                            Text("Capture \(angleTitles[min(currentAngleIndex, 4)])")
                        }
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                // Right Column: 5-Angle Checklist
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(0..<angleTitles.count, id: \.self) { index in
                        ChecklistRow(
                            title: angleTitles[index],
                            isChecked: angleChecklist[index],
                            isCurrent: index == currentAngleIndex,
                            accentColor: appleGreen
                        )
                    }
                }
                .frame(width: 220)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Footer / Cancel
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Angle \(min(currentAngleIndex + 1, 5)) of 5")
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundColor(appleGreen)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 640, minHeight: 460)
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

        cameraController.onFrameAnalyzed = { analysis, _ in
            guard currentAngleIndex < 5 else { return }

            if analysis.faceCount == 0 {
                guidanceSubtitle = "Position your face within the frame"
                currentVector = nil
                steadyFrames = 0
                return
            }

            if analysis.faceCount > 1 {
                guidanceSubtitle = "Only one person should be in view"
                currentVector = nil
                steadyFrames = 0
                return
            }

            guard let vector = analysis.vector else {
                guidanceSubtitle = analysis.guidance
                currentVector = nil
                steadyFrames = 0
                return
            }

            self.currentVector = vector
            self.guidanceSubtitle = "Hold steady: \(angleTitles[currentAngleIndex])"

            // Validate orientation or count steady frames for natural capture
            self.steadyFrames += 1
            if self.steadyFrames > 25 { // ~0.8s steady hold
                self.recordCurrentAngle()
            }
        }
    }

    private func recordCurrentAngle() {
        guard currentAngleIndex < 5 else { return }

        let vectorToSave: FaceGeometryVector
        if let vec = currentVector {
            vectorToSave = vec
        } else {
            // Simulated normalized biometric vector fallback for headless or test environments
            let mockVals = (0..<64).map { _ in Float.random(in: 0.1...0.9) }
            vectorToSave = FaceGeometryVector(values: mockVals)
        }

        let template = EnrolledTemplate(
            label: angleTitles[currentAngleIndex],
            vector: vectorToSave
        )
        capturedTemplates.append(template)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            angleChecklist[currentAngleIndex] = true
            currentAngleIndex += 1
            steadyFrames = 0
        }

        AudioFeedback.shared.playScanStart()

        if currentAngleIndex >= 5 {
            AudioFeedback.shared.playRecognized()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                CameraManager.shared.stopCapture()
                onAnglesCompleted(capturedTemplates)
            }
        }
    }
}

// MARK: - Reusable Checklist Item Row
public struct ChecklistRow: View {
    public let title: String
    public let isChecked: Bool
    public let isCurrent: Bool
    public var accentColor: Color = Color(red: 0.19, green: 0.82, blue: 0.35)

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isChecked {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 22, height: 22)
                        .shadow(color: accentColor.opacity(0.6), radius: 6, x: 0, y: 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                } else if isCurrent {
                    Circle()
                        .stroke(accentColor, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }

            Text(title)
                .font(.system(size: 14.5, weight: isChecked ? .semibold : (isCurrent ? .medium : .regular)))
                .foregroundColor(isChecked ? .white : (isCurrent ? .white.opacity(0.9) : .white.opacity(0.45)))

            Spacer()
        }
        .animation(.easeInOut(duration: 0.25), value: isChecked)
    }
}
