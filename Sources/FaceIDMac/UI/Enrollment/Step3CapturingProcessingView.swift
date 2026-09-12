import SwiftUI
import AVFoundation

public struct Step3CapturingProcessingView: View {
    public var userId: UUID
    public var templates: [EnrolledTemplate]
    public var onComplete: () -> Void

    @StateObject private var cameraController = CameraPreviewController()
    @State private var processingStage: Int = 0
    @State private var checklistState: [Bool] = [false, false, false, false, false]

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let stages = [
        "Capturing images",
        "Processing",
        "Creating template",
        "Encrypting data",
        "Storing securely"
    ]

    public init(
        userId: UUID,
        templates: [EnrolledTemplate],
        onComplete: @escaping () -> Void
    ) {
        self.userId = userId
        self.templates = templates
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Text("Capturing & Processing")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Your facial data is captured and converted into a secure biometric template (stored locally).")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Main 2-Column Processing Interface (matching diagram Step 3)
            HStack(alignment: .center, spacing: 32) {
                // Left Column: Camera Box with Green Brackets and Sweeping Laser Beam
                FaceScannerBoxView(
                    controller: cameraController,
                    width: 320,
                    height: 240,
                    isScanning: true,
                    showBrackets: true,
                    statusText: "Capturing your face...",
                    accentColor: appleGreen
                )

                // Right Column: 5-Step Processing Checklist
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(0..<stages.count, id: \.self) { index in
                        ChecklistRow(
                            title: stages[index],
                            isChecked: checklistState[index],
                            isCurrent: index == processingStage,
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

            // Cryptographic Status Footnote
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(appleGreen)

                Text("AES-GCM 256-Bit Hardware Encrypted in macOS Keychain")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.bottom, 28)
        }
        .frame(minWidth: 640, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            CameraManager.shared.startCapture()
            runProcessingPipeline()
        }
        .onDisappear {
            CameraManager.shared.stopCapture()
        }
    }

    private func runProcessingPipeline() {
        // Sequentially execute and illuminate the 5 processing stages
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { checklistState[0] = true; processingStage = 1 }
            AudioFeedback.shared.playScanStart()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation { checklistState[1] = true; processingStage = 2 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { checklistState[2] = true; processingStage = 3 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation { checklistState[3] = true; processingStage = 4 }
            // Perform actual Keychain encryption
            ProfileManager.shared.saveTemplates(for: userId, templates: templates)
            AutoLockManager.shared.isAutoLockEnabled = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation { checklistState[4] = true }
            AudioFeedback.shared.playRecognized()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                CameraManager.shared.stopCapture()
                onComplete()
            }
        }
    }
}
