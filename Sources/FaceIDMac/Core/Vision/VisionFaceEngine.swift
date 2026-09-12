import Foundation
@preconcurrency import Vision
import CoreMedia
import CoreGraphics

public struct FaceAnalysisResult: @unchecked Sendable {
    public let faceCount: Int
    public let observation: VNFaceObservation?
    public let vector: FaceGeometryVector?
    public let quality: Float
    public let isWellPositioned: Bool
    public let guidance: String
    public let boundingBox: CGRect // Normalized 0..1 in Vision coordinates

    public init(
        faceCount: Int = 0,
        observation: VNFaceObservation? = nil,
        vector: FaceGeometryVector? = nil,
        quality: Float = 0.0,
        isWellPositioned: Bool = false,
        guidance: String = "Looking for you…",
        boundingBox: CGRect = .zero
    ) {
        self.faceCount = faceCount
        self.observation = observation
        self.vector = vector
        self.quality = quality
        self.isWellPositioned = isWellPositioned
        self.guidance = guidance
        self.boundingBox = boundingBox
    }
}

public final class VisionFaceEngine: @unchecked Sendable {
    private let sequenceHandler = VNSequenceRequestHandler()
    private let lock = NSLock()

    public init() {}

    /// Analyze a video frame buffer
    public func analyze(sampleBuffer: CMSampleBuffer, orientation: CGImagePropertyOrientation = .up) -> FaceAnalysisResult {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return FaceAnalysisResult(guidance: "Camera feed unavailable")
        }
        return analyze(pixelBuffer: pixelBuffer, orientation: orientation)
    }

    /// Analyze pixel buffer directly
    public func analyze(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) -> FaceAnalysisResult {
        lock.lock()
        defer { lock.unlock() }

        // Setup requests: Face landmarks + Face capture quality
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()

        let requests: [VNRequest] = [landmarksRequest, qualityRequest]

        do {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            try handler.perform(requests)

            guard let faceResults = landmarksRequest.results, !faceResults.isEmpty else {
                return FaceAnalysisResult(faceCount: 0, guidance: "Looking for you…")
            }

            // Exactly one face verification
            if faceResults.count > 1 {
                return FaceAnalysisResult(
                    faceCount: faceResults.count,
                    guidance: "Multiple faces detected. Please ensure only one person is in view."
                )
            }

            let primaryFace = faceResults[0]
            let box = primaryFace.boundingBox

            // Extract capture quality if available
            var qualityScore: Float = 0.8
            if let qualityResults = qualityRequest.results, let qFace = qualityResults.first {
                qualityScore = qFace.faceCaptureQuality ?? 0.8
            }

            // Positioning & sizing checks
            // Normalized Vision coords: origin is bottom-left, (0,0) to (1,1)
            let faceCenterX = box.midX
            let faceCenterY = box.midY
            let faceWidth = box.width
            let faceHeight = box.height

            var guidance = "Looking good."
            var isPositioned = true

            // Size checks
            if faceWidth < 0.18 || faceHeight < 0.18 {
                guidance = "Move closer to the camera"
                isPositioned = false
            } else if faceWidth > 0.80 || faceHeight > 0.80 {
                guidance = "Move slightly back"
                isPositioned = false
            } else if faceCenterX < 0.25 {
                guidance = "Move slightly to the right"
                isPositioned = false
            } else if faceCenterX > 0.75 {
                guidance = "Move slightly to the left"
                isPositioned = false
            } else if faceCenterY < 0.20 {
                guidance = "Raise your camera or head"
                isPositioned = false
            } else if faceCenterY > 0.80 {
                guidance = "Lower your camera or head"
                isPositioned = false
            } else if qualityScore < 0.35 {
                guidance = "Ensure your face is well lit"
                isPositioned = false
            }

            // Extract geometric biometric vector
            let vector = FaceGeometryVector.extract(from: primaryFace, captureQuality: qualityScore)

            return FaceAnalysisResult(
                faceCount: 1,
                observation: primaryFace,
                vector: vector,
                quality: qualityScore,
                isWellPositioned: isPositioned,
                guidance: guidance,
                boundingBox: box
            )
        } catch {
            return FaceAnalysisResult(guidance: "Vision processing error")
        }
    }
}
