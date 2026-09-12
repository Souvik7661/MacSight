import SwiftUI

public struct Step4FaceEnrolledView: View {
    public var onDone: () -> Void
    public var onTestLock: () -> Void

    private let appleGreen = Color(red: 0.19, green: 0.82, blue: 0.35)

    public init(onDone: @escaping () -> Void, onTestLock: @escaping () -> Void) {
        self.onDone = onDone
        self.onTestLock = onTestLock
    }

    public var body: some View {
        ZStack {
            // macOS Monterey/Sonoma Dark Purple Dunes Aesthetic Background
            MacWallpaperDunesView()
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                Spacer()

                // Big Glowing Green Checkmark Circle
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [appleGreen.opacity(0.32), Color.clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)

                    Circle()
                        .stroke(appleGreen, lineWidth: 3.5)
                        .frame(width: 88, height: 88)
                        .shadow(color: appleGreen.opacity(0.8), radius: 14, x: 0, y: 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(appleGreen)
                        .shadow(color: appleGreen.opacity(0.9), radius: 10, x: 0, y: 0)
                }
                .padding(.bottom, 6)

                // Title & Subtitle
                VStack(spacing: 10) {
                    Text("Face Enrolled Successfully!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                    Text("You can now use your face to unlock your Mac.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }

                Spacer()

                // Action Buttons (Vibrant Green "Done")
                VStack(spacing: 12) {
                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(appleGreen)
                                    .shadow(color: appleGreen.opacity(0.4), radius: 10, x: 0, y: 4)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onTestLock) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                            Text("Lock Mac Now (Test Face ID)")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 280)
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 24)
        }
        .frame(minWidth: 580, minHeight: 520)
    }
}

// MARK: - Reusable macOS Dunes Wallpaper Background
public struct MacWallpaperDunesView: View {
    public init() {}

    public var body: some View {
        ZStack {
            // Base dark blue/purple gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.07, blue: 0.16),
                    Color(red: 0.15, green: 0.09, blue: 0.28),
                    Color(red: 0.28, green: 0.14, blue: 0.38),
                    Color(red: 0.12, green: 0.06, blue: 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Ambient horizon glow
            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.24, blue: 0.55).opacity(0.4),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 500
            )

            // Dune wave silhouettes
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height * 0.65))
                    path.addCurve(
                        to: CGPoint(x: geo.size.width, y: geo.size.height * 0.78),
                        control1: CGPoint(x: geo.size.width * 0.35, y: geo.size.height * 0.55),
                        control2: CGPoint(x: geo.size.width * 0.75, y: geo.size.height * 0.85)
                    )
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.08, blue: 0.28).opacity(0.85),
                            Color(red: 0.06, green: 0.03, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height * 0.78))
                    path.addCurve(
                        to: CGPoint(x: geo.size.width, y: geo.size.height * 0.70),
                        control1: CGPoint(x: geo.size.width * 0.3, y: geo.size.height * 0.88),
                        control2: CGPoint(x: geo.size.width * 0.7, y: geo.size.height * 0.62)
                    )
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.05, blue: 0.18).opacity(0.95),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}
