import SwiftUI

public struct OnboardingView: View {
    public var onStartSetup: () -> Void
    public var onDismiss: () -> Void

    @State private var lottieState: FaceIDVisualState = .searching

    public init(onStartSetup: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onStartSetup = onStartSetup
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Centered Face ID Animated Glyphs
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                FaceIDLottieView(state: $lottieState)
                    .frame(width: 140, height: 140)
            }
            .padding(.bottom, 16)

            // Header Titles
            Text("Face ID for Mac")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.bottom, 6)

            Text("Unlock your workspace with a glance.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 28)

            // Privacy & Feature Highlights
            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    color: .blue,
                    title: "On-Device Biometrics",
                    description: "Face ID for Mac uses your camera to recognize you on this device. Your face data stays on this Mac."
                )

                FeatureRow(
                    icon: "key.fill",
                    color: .green,
                    title: "Hardware-Backed Security",
                    description: "Biometric vectors are encrypted using AES-GCM and protected in the macOS Keychain."
                )

                FeatureRow(
                    icon: "eye.fill",
                    color: .purple,
                    title: "Liveness Verification",
                    description: "Advanced anti-spoofing technology ensures photographs and screens cannot unlock your device."
                )
            }
            .frame(maxWidth: 440)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.bottom, 36)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: onStartSetup) {
                    Text("Set Up Face ID")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Not Now")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .frame(maxWidth: 320)
            .padding(.bottom, 32)
        }
        .frame(width: 580, height: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
