import SwiftUI
import AVFoundation
import AppKit

public struct Step1LaunchPermissionsView: View {
    public var onContinue: () -> Void
    public var onOpenShowcase: () -> Void

    @State private var hasCameraAccess: Bool = false
    @State private var hasAccessibilityAccess: Bool = false
    @State private var checkTimer: Timer?

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)

    public init(onContinue: @escaping () -> Void, onOpenShowcase: @escaping () -> Void) {
        self.onContinue = onContinue
        self.onOpenShowcase = onOpenShowcase
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header Section with Apple Face ID Animated Icon
            VStack(spacing: 12) {
                AnimatedFaceIDGIFView(size: 96, glowColor: appleGreen)
                    .frame(height: 96)

                Text("Mac Face ID")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Your Face. Your Access.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.bottom, 28)

            // Permission Items Box
            VStack(spacing: 14) {
                PermissionCardRow(
                    icon: "camera.fill",
                    title: "Camera Access",
                    subtitle: "Required to detect and recognize your face",
                    isGranted: hasCameraAccess,
                    onToggle: requestCameraAccess
                )

                PermissionCardRow(
                    icon: "lock.shield.fill",
                    title: "Accessibility Access",
                    subtitle: "Required to unlock your Mac",
                    isGranted: hasAccessibilityAccess,
                    onToggle: requestAccessibilityAccess
                )
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)

            Spacer()

            // Main Action Button (Vibrant Apple Green)
            VStack(spacing: 12) {
                Button(action: handlePrimaryButton) {
                    HStack(spacing: 8) {
                        Text(allGranted ? "Continue to Enrollment" : "Grant Permissions")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: allGranted ? "arrow.right" : "checkmark.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(appleGreen)
                            .shadow(color: appleGreen.opacity(0.4), radius: 10, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)

                // Secondary showcase & test button
                Button(action: onOpenShowcase) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2")
                        Text("View 8-Step Interactive Diagram")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 340)
            .padding(.bottom, 32)
        }
        .frame(minWidth: 580, minHeight: 600)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                RadialGradient(
                    colors: [appleGreen.opacity(0.06), Color.clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 400
                )
            }
            .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            refreshPermissions()
            startPermissionPolling()
        }
        .onDisappear {
            checkTimer?.invalidate()
            checkTimer = nil
        }
    }

    private var allGranted: Bool {
        hasCameraAccess && hasAccessibilityAccess
    }

    private func refreshPermissions() {
        // Camera Status
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        hasCameraAccess = (status == .authorized)

        // Accessibility Status
        hasAccessibilityAccess = AXIsProcessTrusted()
    }

    private func startPermissionPolling() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.refreshPermissions()
        }
    }

    private func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasCameraAccess = granted
                    if self.allGranted {
                        self.onContinue()
                    }
                }
            }
        } else if status == .denied || status == .restricted {
            CameraManager.shared.openSystemCameraSettings()
        }
    }

    private func requestAccessibilityAccess() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let access = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityAccess = access
        if !access {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func handlePrimaryButton() {
        if !hasCameraAccess {
            requestCameraAccess()
        }
        if !hasAccessibilityAccess {
            requestAccessibilityAccess()
        }

        // If camera is granted (or user is running in test/sandbox environment), proceed
        if hasCameraAccess || CommandLine.arguments.contains("--mock-camera") {
            onContinue()
        } else {
            // Still allow proceeding to enrollment with simulated/fallback frame if desired
            onContinue()
        }
    }
}

// MARK: - Permission Card Row
struct PermissionCardRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let onToggle: () -> Void

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isGranted ? appleGreen.opacity(0.18) : Color.white.opacity(0.08))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isGranted ? appleGreen : .white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            Button(action: onToggle) {
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(appleGreen)
                } else {
                    Text("Grant")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isGranted ? appleGreen.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
