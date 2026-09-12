import Foundation
import Vision
import Accelerate

/// A 64-dimensional scale- and translation-invariant normalized facial biometric vector.
public struct FaceGeometryVector: Codable, Equatable, Sendable {
    public let values: [Float]
    public let roll: Float
    public let yaw: Float
    public let pitch: Float
    public let captureQuality: Float
    public let timestamp: Date

    public init(values: [Float], roll: Float = 0, yaw: Float = 0, pitch: Float = 0, captureQuality: Float = 1.0, timestamp: Date = Date()) {
        // Ensure L2 normalization
        var norm: Float = 0.0
        vDSP_svesq(values, 1, &norm, vDSP_Length(values.count))
        norm = sqrt(norm)

        if norm > 0.0001 {
            var normalized = [Float](repeating: 0, count: values.count)
            var divisor = norm
            vDSP_vsdiv(values, 1, &divisor, &normalized, 1, vDSP_Length(values.count))
            self.values = normalized
        } else {
            self.values = values
        }

        self.roll = roll
        self.yaw = yaw
        self.pitch = pitch
        self.captureQuality = captureQuality
        self.timestamp = timestamp
    }

    /// Compute cosine similarity between two normalized biometric vectors (1.0 = identical, 0.0 = orthogonal)
    public func similarity(to other: FaceGeometryVector) -> Float {
        guard self.values.count == other.values.count, !self.values.isEmpty else { return 0 }
        var dot: Float = 0.0
        vDSP_dotpr(self.values, 1, other.values, 1, &dot, vDSP_Length(self.values.count))
        return max(0.0, min(1.0, dot))
    }

    /// Static mock vector for testing and initial fallback enrollment
    public static func mockValid() -> FaceGeometryVector {
        let raw = (0..<64).map { Float($0) * 1.5 + 2.0 }
        return FaceGeometryVector(values: raw)
    }

    /// Factory method to extract geometry from a Vision face observation
    public static func extract(from observation: VNFaceObservation, captureQuality: Float = 1.0) -> FaceGeometryVector? {
        guard let landmarks = observation.landmarks else { return nil }

        // Core landmark regions
        guard let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye,
              let nose = landmarks.nose,
              let outerLips = landmarks.outerLips else {
            return nil
        }

        // Helper to compute centroid of normalized points
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
        let iod = dist(leftEyeCenter, rightEyeCenter) // Inter-Ocular Distance
        guard iod > 0.01 else { return nil }

        let noseCenter = centroid(nose.normalizedPoints)
        let mouthCenter = centroid(outerLips.normalizedPoints)

        var rawValues: [Float] = []
        rawValues.reserveCapacity(64)

        // 1. Proportional Distance Ratios (normalized by IOD)
        rawValues.append(dist(noseCenter, mouthCenter) / iod)
        rawValues.append(dist(leftEyeCenter, noseCenter) / iod)
        rawValues.append(dist(rightEyeCenter, noseCenter) / iod)
        rawValues.append(dist(leftEyeCenter, mouthCenter) / iod)
        rawValues.append(dist(rightEyeCenter, mouthCenter) / iod)

        // Mouth proportions
        if let firstLip = outerLips.normalizedPoints.first, let midLip = outerLips.normalizedPoints.dropFirst(outerLips.normalizedPoints.count / 2).first {
            rawValues.append(dist(firstLip, midLip) / iod)
        } else {
            rawValues.append(0.5)
        }

        // Eyebrows
        if let leftEyebrow = landmarks.leftEyebrow, let rightEyebrow = landmarks.rightEyebrow {
            let leftBrowCenter = centroid(leftEyebrow.normalizedPoints)
            let rightBrowCenter = centroid(rightEyebrow.normalizedPoints)
            rawValues.append(dist(leftBrowCenter, leftEyeCenter) / iod)
            rawValues.append(dist(rightBrowCenter, rightEyeCenter) / iod)
            rawValues.append(dist(leftBrowCenter, rightBrowCenter) / iod)
        } else {
            rawValues.append(contentsOf: [0.3, 0.3, 1.0])
        }

        // Nose crest
        if let noseCrest = landmarks.noseCrest, let top = noseCrest.normalizedPoints.first, let bottom = noseCrest.normalizedPoints.last {
            rawValues.append(dist(top, bottom) / iod)
        } else {
            rawValues.append(0.4)
        }

        // Face contour (jawline)
        if let faceContour = landmarks.faceContour {
            let contourPoints = faceContour.normalizedPoints
            if contourPoints.count >= 9 {
                let step = max(1, contourPoints.count / 8)
                for i in 0..<8 {
                    let idx = min(contourPoints.count - 1, i * step)
                    let p = contourPoints[idx]
                    rawValues.append(dist(p, noseCenter) / iod)
                    rawValues.append(dist(p, mouthCenter) / iod)
                }
            }
        }

        // Detailed Normalized Offsets relative to nose center (scale-invariant via IOD)
        func addNormalizedOffsets(_ points: [CGPoint], maxCount: Int) {
            let step = max(1, points.count / maxCount)
            for i in 0..<maxCount {
                let idx = min(points.count - 1, i * step)
                let p = points[idx]
                rawValues.append(Float(p.x - noseCenter.x) / iod)
                rawValues.append(Float(p.y - noseCenter.y) / iod)
            }
        }

        addNormalizedOffsets(leftEye.normalizedPoints, maxCount: 4)
        addNormalizedOffsets(rightEye.normalizedPoints, maxCount: 4)
        addNormalizedOffsets(outerLips.normalizedPoints, maxCount: 6)
        if let noseCrest = landmarks.noseCrest {
            addNormalizedOffsets(noseCrest.normalizedPoints, maxCount: 4)
        }

        // Pad or trim to exactly 64 values
        if rawValues.count < 64 {
            rawValues.append(contentsOf: [Float](repeating: 0.0, count: 64 - rawValues.count))
        } else if rawValues.count > 64 {
            rawValues = Array(rawValues.prefix(64))
        }

        let roll = observation.roll?.floatValue ?? 0
        let yaw = observation.yaw?.floatValue ?? 0
        let pitch = observation.pitch?.floatValue ?? 0

        return FaceGeometryVector(
            values: rawValues,
            roll: roll,
            yaw: yaw,
            pitch: pitch,
            captureQuality: captureQuality,
            timestamp: Date()
        )
    }
}
