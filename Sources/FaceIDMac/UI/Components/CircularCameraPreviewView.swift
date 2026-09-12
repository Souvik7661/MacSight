import SwiftUI
import AVFoundation
import Vision
import CoreImage

public final class CameraPreviewController: ObservableObject, @unchecked Sendable {
    @Published public var currentFrame: NSImage?
    @Published public var latestAnalysis: FaceAnalysisResult = FaceAnalysisResult()

    public var onFrameAnalyzed: ((FaceAnalysisResult, CMSampleBuffer) -> Void)?

    private let visionEngine = VisionFaceEngine()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var isProcessing = false
    private let lock = NSLock()
    private var listenerId: UUID?

    public init() {
        self.listenerId = CameraManager.shared.addListener { [weak self] sampleBuffer in
            self?.processSampleBuffer(sampleBuffer)
        }
    }

    deinit {
        if let id = listenerId {
            CameraManager.shared.removeListener(id)
        }
    }

    public func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        guard !isProcessing else {
            lock.unlock()
            return
        }
        isProcessing = true
        lock.unlock()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        // Run vision analysis
        let analysis = visionEngine.analyze(pixelBuffer: pixelBuffer)

        // Convert to NSImage for preview (mirrored for natural selfie view)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(.upMirrored)

        var nsImage: NSImage? = nil
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        if let cgImage = ciContext.createCGImage(ciImage, from: rect) {
            nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentFrame = nsImage
            self.latestAnalysis = analysis
            self.onFrameAnalyzed?(analysis, sampleBuffer)
            self.lock.lock()
            self.isProcessing = false
            self.lock.unlock()
        }
    }
}

public struct CircularCameraPreviewView: View {
    @ObservedObject public var controller: CameraPreviewController
    public var size: CGFloat = 280
    public var showLandmarks: Bool = true
    public var showBrackets: Bool = true

    @State private var scanLineOffset: CGFloat = -140

    public init(
        controller: CameraPreviewController,
        size: CGFloat = 280,
        showLandmarks: Bool = true,
        showBrackets: Bool = true
    ) {
        self.controller = controller
        self.size = size
        self.showLandmarks = showLandmarks
        self.showBrackets = showBrackets
    }

    public var body: some View {
        ZStack {
            // Dark outer vignette background
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                .frame(width: size, height: size)
                .shadow(color: Color.blue.opacity(0.15), radius: 24, x: 0, y: 8)

            // Live Camera Feed inside Circle
            if let image = controller.currentFrame {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        // Inner Apple-style glass vignette
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.white.opacity(0.05),
                                        Color.blue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            } else {
                // Placeholder when camera is warming up
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: size, height: size)

                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Activating Camera…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Landmarks overlay
            if showLandmarks, let landmarks = controller.latestAnalysis.observation?.landmarks {
                FaceLandmarksOverlay(landmarks: landmarks, size: size)
            }

            // Scanning Laser Beam Animation
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.blue.opacity(0.35),
                            Color.cyan.opacity(0.7),
                            Color.blue.opacity(0.35),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.85, height: 2)
                .offset(y: scanLineOffset)
                .clipShape(Circle())
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 2.2)
                            .repeatForever(autoreverses: true)
                    ) {
                        scanLineOffset = 140
                    }
                }

            // Detection Target Frame Brackets
            if showBrackets {
                TargetBrackets(size: size * 0.88, isAligned: controller.latestAnalysis.isWellPositioned)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Animated Face ID Target Brackets
struct TargetBrackets: View {
    let size: CGFloat
    let isAligned: Bool

    var bracketColor: Color {
        isAligned ? Color.green.opacity(0.85) : Color.white.opacity(0.4)
    }

    var body: some View {
        ZStack {
            ForEach(0..<4) { index in
                BracketCorner()
                    .stroke(
                        bracketColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(Double(index * 90)))
                    .offset(
                        x: index == 0 || index == 3 ? -size / 2 + 14 : size / 2 - 14,
                        y: index < 2 ? -size / 2 + 14 : size / 2 - 14
                    )
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.3), value: isAligned)
    }
}

struct BracketCorner: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 6))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 6, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Subtle Landmark Points Overlay
struct FaceLandmarksOverlay: View {
    let landmarks: VNFaceLandmarks2D
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            // Draw subtle glowing dots on eyes and nose
            func drawPoints(_ points: [CGPoint]?, color: Color) {
                guard let points = points else { return }
                for p in points {
                    // Normalize to canvas center
                    // Note: Vision coords are bottom-left (0..1), mirrored for selfie
                    let x = (1.0 - p.x) * canvasSize.width
                    let y = (1.0 - p.y) * canvasSize.height
                    let rect = CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }

            if let leftEye = landmarks.leftEye?.normalizedPoints {
                drawPoints(leftEye, color: Color.cyan.opacity(0.6))
            }
            if let rightEye = landmarks.rightEye?.normalizedPoints {
                drawPoints(rightEye, color: Color.cyan.opacity(0.6))
            }
            if let nose = landmarks.nose?.normalizedPoints {
                drawPoints(nose, color: Color.blue.opacity(0.5))
            }
            if let lips = landmarks.outerLips?.normalizedPoints {
                drawPoints(lips, color: Color.white.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
