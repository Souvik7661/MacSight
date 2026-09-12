import SwiftUI
import Vision
import AppKit

public struct FaceScannerBoxView: View {
    @ObservedObject public var controller: CameraPreviewController
    public var width: CGFloat
    public var height: CGFloat
    public var isScanning: Bool
    public var showBrackets: Bool
    public var statusText: String?
    public var secondaryText: String?
    public var progress: Double? // nil for none, 0.0...1.0 for progress bar
    public var accentColor: Color

    @State private var scanBeamOffset: CGFloat = -1
    @State private var pulseScale: CGFloat = 1.0

    public init(
        controller: CameraPreviewController,
        width: CGFloat = 340,
        height: CGFloat = 255,
        isScanning: Bool = false,
        showBrackets: Bool = true,
        statusText: String? = nil,
        secondaryText: String? = nil,
        progress: Double? = nil,
        accentColor: Color = Color(red: 0.19, green: 0.82, blue: 0.35) // Apple Green #30D158
    ) {
        self.controller = controller
        self.width = width
        self.height = height
        self.isScanning = isScanning
        self.showBrackets = showBrackets
        self.statusText = statusText
        self.secondaryText = secondaryText
        self.progress = progress
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Main Camera Box with rounded corners
            ZStack {
                // Background dark placeholder
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.85))
                    .frame(width: width, height: height)

                // Live Camera Stream
                if let frame = controller.currentFrame {
                    Image(nsImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.85)
                        Text("Activating Mac Camera…")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Inner subtle vignette border
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), Color.white.opacity(0.04), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: width, height: height)

                // Face Reticle Corner Brackets [  ]
                if showBrackets {
                    FaceReticleBrackets(accentColor: accentColor)
                        .frame(width: width * 0.68, height: height * 0.74)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulseScale)
                        .onAppear {
                            pulseScale = 1.03
                        }
                }

                // Sweeping Green Laser Scanning Beam
                if isScanning {
                    GeometryReader { geo in
                        let beamHeight: CGFloat = 32
                        let maxY = geo.size.height - beamHeight

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.0),
                                        accentColor.opacity(0.28),
                                        accentColor.opacity(0.9),
                                        accentColor.opacity(0.28),
                                        accentColor.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: geo.size.width, height: beamHeight)
                            .overlay(
                                // Crisp laser line in center
                                Rectangle()
                                    .fill(Color.white.opacity(0.95))
                                    .frame(height: 2)
                                    .shadow(color: accentColor, radius: 8, y: 0)
                            )
                            .offset(y: scanBeamOffset >= 0 ? scanBeamOffset * maxY : 0)
                            .animation(
                                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                value: scanBeamOffset
                            )
                            .onAppear {
                                scanBeamOffset = 1.0
                            }
                    }
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .frame(width: width, height: height)
            .shadow(color: accentColor.opacity(isScanning ? 0.35 : 0.15), radius: 18, x: 0, y: 8)

            // Subtitles below camera frame
            if let primary = statusText {
                Text(primary)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
            }

            if let secondary = secondaryText {
                Text(secondary)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Horizontal Glowing Progress Bar (for Stage 7: Authenticating)
            if let prog = progress {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor.opacity(0.8), accentColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(prog))), height: 6)
                                .shadow(color: accentColor.opacity(0.8), radius: 6, x: 0, y: 0)
                                .animation(.easeOut(duration: 0.2), value: prog)
                        }
                    }
                    .frame(width: width * 0.75, height: 6)
                }
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Apple-Style Green Corner Brackets [  ]
public struct FaceReticleBrackets: View {
    public var accentColor: Color = Color(red: 0.19, green: 0.82, blue: 0.35)
    public var lineWidth: CGFloat = 3.5
    public var cornerLength: CGFloat = 28
    public var cornerRadius: CGFloat = 14

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Top-Left Bracket
                Path { path in
                    path.move(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                    path.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0), control: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))
                }
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                // Top-Right Bracket
                Path { path in
                    path.move(to: CGPoint(x: w - cornerLength, y: 0))
                    path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
                    path.addQuadCurve(to: CGPoint(x: w, y: cornerRadius), control: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: cornerLength))
                }
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                // Bottom-Left Bracket
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h - cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: h - cornerRadius))
                    path.addQuadCurve(to: CGPoint(x: cornerRadius, y: h), control: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: cornerLength, y: h))
                }
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                // Bottom-Right Bracket
                Path { path in
                    path.move(to: CGPoint(x: w - cornerLength, y: h))
                    path.addLine(to: CGPoint(x: w - cornerRadius, y: h))
                    path.addQuadCurve(to: CGPoint(x: w, y: h - cornerRadius), control: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - cornerLength))
                }
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            .shadow(color: accentColor.opacity(0.8), radius: 6, x: 0, y: 0)
        }
    }
}
