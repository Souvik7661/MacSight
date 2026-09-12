import SwiftUI
import AVFoundation

public struct CameraPermissionView: View {
    @State private var permissionState: CameraPermissionState = CameraManager.shared.permissionState
    public var onGranted: () -> Void
    public var onBack: () -> Void

    public init(onGranted: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onGranted = onGranted
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: iconName)
                    .font(.system(size: 54))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(subtitleText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            if permissionState == .denied || permissionState == .restricted {
                VStack(spacing: 12) {
                    Text("To allow camera access, open System Settings → Privacy & Security → Camera, and enable Face ID for Mac.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button(action: {
                        CameraManager.shared.openSystemCameraSettings()
                    }) {
                        Label("Open System Settings", systemImage: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
            }

            Spacer()

            VStack(spacing: 12) {
                if permissionState == .notDetermined {
                    Button(action: requestPermission) {
                        Text("Allow Camera Access")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else if permissionState == .denied || permissionState == .restricted {
                    Button(action: checkAgain) {
                        Text("Check Permission Again")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else if permissionState == .authorized {
                    Button(action: onGranted) {
                        Text("Continue to Enrollment")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 13.5))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 300)
            .padding(.bottom, 32)
        }
        .frame(width: 580, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            CameraManager.shared.updatePermissionState()
            self.permissionState = CameraManager.shared.permissionState
        }
    }

    private var iconName: String {
        switch permissionState {
        case .authorized: return "checkmark.circle.fill"
        case .denied, .restricted: return "camera.badge.ellipsis"
        case .unavailable: return "video.slash.fill"
        case .notDetermined: return "camera.fill"
        }
    }

    private var iconColor: Color {
        switch permissionState {
        case .authorized: return .green
        case .denied, .restricted: return .orange
        case .unavailable: return .red
        case .notDetermined: return .blue
        }
    }

    private var titleText: String {
        switch permissionState {
        case .authorized: return "Camera Access Enabled"
        case .denied, .restricted: return "Camera Access Required"
        case .unavailable: return "No Camera Available"
        case .notDetermined: return "Camera Access"
        }
    }

    private var subtitleText: String {
        switch permissionState {
        case .authorized:
            return "Face ID for Mac is ready to enroll your face."
        case .denied, .restricted:
            return "Face ID for Mac needs access to your camera to recognize you. Camera access was previously denied."
        case .unavailable:
            return "Please connect a camera or verify another application is not exclusively locking it."
        case .notDetermined:
            return "Face ID for Mac needs access to your camera to recognize you."
        }
    }

    private func requestPermission() {
        CameraManager.shared.requestCameraPermission { granted in
            self.permissionState = CameraManager.shared.permissionState
            if granted {
                onGranted()
            }
        }
    }

    private func checkAgain() {
        CameraManager.shared.updatePermissionState()
        self.permissionState = CameraManager.shared.permissionState
        if permissionState == .authorized {
            onGranted()
        }
    }
}
