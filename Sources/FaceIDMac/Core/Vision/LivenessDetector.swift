import Foundation
import Vision

public enum LivenessStatus: Equatable, Sendable {
    case idle
    case analyzing(progress: Float, hint: String)
    case passed(blinkDetected: Bool, motionScore: Float)
    case failed(reason: String)

    public var isPassed: Bool {
        if case .passed = self { return true }
        return false
    }
}

public final class LivenessDetector: @unchecked Sendable {
    public struct Config: Sendable {
        public var requireBlink: Bool = false
        public var earBlinkThreshold: Float = 0.18
        public var earOpenThreshold: Float = 0.24
        public var minPoseVariance: Float = 0.00015
        public var historyLength: Int = 20

        public init(
            requireBlink: Bool = false,
            earBlinkThreshold: Float = 0.18,
            earOpenThreshold: Float = 0.24,
            minPoseVariance: Float = 0.00015,
            historyLength: Int = 20
        ) {
            self.requireBlink = requireBlink
            self.earBlinkThreshold = earBlinkThreshold
            self.earOpenThreshold = earOpenThreshold
            self.minPoseVariance = minPoseVariance
            self.historyLength = historyLength
        }
    }

    public var config: Config
    private let lock = NSLock()

    // State tracking
    private var earHistory: [Float] = []
    private var yawHistory: [Float] = []
    private var pitchHistory: [Float] = []
    private var rollHistory: [Float] = []
    private var blinkDetected = false
    private var blinkCount = 0
    private var eyesWereClosed = false
    private var frameCount = 0

    public init(config: Config = Config()) {
        self.config = config
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        earHistory.removeAll()
        yawHistory.removeAll()
        pitchHistory.removeAll()
        rollHistory.removeAll()
        blinkDetected = false
        blinkCount = 0
        eyesWereClosed = false
        frameCount = 0
    }

    /// Process a new face observation frame and assess liveness
    public func processFrame(observation: VNFaceObservation) -> LivenessStatus {
        lock.lock()
        defer { lock.unlock() }

        frameCount += 1

        guard let landmarks = observation.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return .analyzing(progress: 0.1, hint: "Keep face visible")
        }

        // 1. Calculate Eye Aspect Ratio (EAR)
        let leftEAR = calculateEAR(points: leftEye.normalizedPoints)
        let rightEAR = calculateEAR(points: rightEye.normalizedPoints)
        let avgEAR = (leftEAR + rightEAR) / 2.0

        earHistory.append(avgEAR)
        if earHistory.count > config.historyLength {
            earHistory.removeFirst()
        }

        // Blink state machine
        if avgEAR < config.earBlinkThreshold {
            eyesWereClosed = true
        } else if eyesWereClosed && avgEAR > config.earOpenThreshold {
            blinkDetected = true
            blinkCount += 1
            eyesWereClosed = false
        }

        // 2. Track Head Pose Dynamics
        let yaw = observation.yaw?.floatValue ?? 0
        let pitch = observation.pitch?.floatValue ?? 0
        let roll = observation.roll?.floatValue ?? 0

        yawHistory.append(yaw)
        pitchHistory.append(pitch)
        rollHistory.append(roll)

        if yawHistory.count > config.historyLength { yawHistory.removeFirst() }
        if pitchHistory.count > config.historyLength { pitchHistory.removeFirst() }
        if rollHistory.count > config.historyLength { rollHistory.removeFirst() }

        let yawVar = variance(yawHistory)
        let pitchVar = variance(pitchHistory)
        let rollVar = variance(rollHistory)
        let totalPoseVariance = yawVar + pitchVar + rollVar

        let progress = min(1.0, Float(frameCount) / Float(config.historyLength))

        // Check if sufficient frames have been collected
        if frameCount < 10 {
            return .analyzing(progress: progress, hint: "Looking at camera…")
        }

        // Liveness evaluation
        let motionPassed = totalPoseVariance >= config.minPoseVariance

        if config.requireBlink {
            if !blinkDetected {
                return .analyzing(progress: progress, hint: "Please blink naturally")
            }
            if motionPassed || blinkDetected {
                return .passed(blinkDetected: blinkDetected, motionScore: totalPoseVariance)
            }
        } else {
            // General passive liveness: requires natural human micro-variation
            if motionPassed || blinkDetected || totalPoseVariance > (config.minPoseVariance * 0.5) {
                return .passed(blinkDetected: blinkDetected, motionScore: totalPoseVariance)
            }
        }

        // If history is full and absolutely static (potential photo)
        if frameCount >= config.historyLength && !motionPassed && !blinkDetected {
            return .failed(reason: "Liveness check failed: static image suspected")
        }

        return .analyzing(progress: progress, hint: "Verifying live presence…")
    }

    private func calculateEAR(points: [CGPoint]) -> Float {
        guard points.count >= 6 else { return 0.3 }
        // Standard 6-point eye contour:
        // p0: left corner, p3: right corner
        // p1, p2: top contour; p5, p4: bottom contour
        let p0 = points[0]
        let p1 = points[1]
        let p2 = points[2]
        let p3 = points[3]
        let p4 = points[4]
        let p5 = points[5]

        func d(_ a: CGPoint, _ b: CGPoint) -> Float {
            let dx = Float(a.x - b.x)
            let dy = Float(a.y - b.y)
            return sqrt(dx * dx + dy * dy)
        }

        let vertical1 = d(p1, p5)
        let vertical2 = d(p2, p4)
        let horizontal = d(p0, p3)

        guard horizontal > 0.001 else { return 0.3 }
        return (vertical1 + vertical2) / (2.0 * horizontal)
    }

    private func variance(_ values: [Float]) -> Float {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let sumSquaredDiff = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSquaredDiff / Float(values.count)
    }
}
