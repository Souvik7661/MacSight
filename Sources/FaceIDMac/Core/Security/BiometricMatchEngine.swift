import Foundation
import LocalAuthentication
import Combine

public enum MatchResult: Equatable, Sendable {
    case noFace
    case analyzing(guidance: String)
    case livenessRequired(hint: String)
    case authenticated(user: UserProfile, confidence: Float)
    case notRecognized(attempts: Int)
    case lockedOut(remainingCooldown: TimeInterval)
}

public final class BiometricMatchEngine: ObservableObject, @unchecked Sendable {
    public static let shared = BiometricMatchEngine()

    public struct Settings: Sendable {
        public var sensitivityThreshold: Float = 0.88 // Conservative default (0.84 = Low, 0.88 = Normal, 0.92 = High)
        public var requiredConsecutiveFrames: Int = 3
        public var maxFailedAttempts: Int = 5
        public var lockoutDuration: TimeInterval = 30.0
        public var requireLiveness: Bool = true

        public init(
            sensitivityThreshold: Float = 0.88,
            requiredConsecutiveFrames: Int = 3,
            maxFailedAttempts: Int = 5,
            lockoutDuration: TimeInterval = 30.0,
            requireLiveness: Bool = true
        ) {
            self.sensitivityThreshold = sensitivityThreshold
            self.requiredConsecutiveFrames = requiredConsecutiveFrames
            self.maxFailedAttempts = maxFailedAttempts
            self.lockoutDuration = lockoutDuration
            self.requireLiveness = requireLiveness
        }
    }

    @Published public var currentResult: MatchResult = .noFace
    @Published public var failedAttempts: Int = 0
    @Published public var isLockedOut: Bool = false
    @Published public var lockoutTimeRemaining: TimeInterval = 0

    public var settings = Settings()
    private let livenessDetector = LivenessDetector()
    private var consecutiveMatches: [UUID: Int] = [:]
    private var lockoutTimer: Timer?
    private var lockoutEndTime: Date?
    private let lock = NSLock()

    public init() {}

    public func resetSession() {
        lock.lock()
        defer { lock.unlock() }
        consecutiveMatches.removeAll()
        livenessDetector.reset()
        currentResult = .noFace
    }

    /// Process a frame vector and determine if an enrolled user matches
    public func evaluateFrame(
        analysis: FaceAnalysisResult,
        profiles: [UserProfile]
    ) -> MatchResult {
        lock.lock()
        defer { lock.unlock() }

        // Check if currently locked out
        if let lockoutEnd = lockoutEndTime {
            let remaining = lockoutEnd.timeIntervalSinceNow
            if remaining > 0 {
                let res = MatchResult.lockedOut(remainingCooldown: remaining)
                DispatchQueue.main.async {
                    self.isLockedOut = true
                    self.lockoutTimeRemaining = remaining
                    self.currentResult = res
                }
                return res
            } else {
                lockoutEndTime = nil
                failedAttempts = 0
                DispatchQueue.main.async {
                    self.isLockedOut = false
                    self.lockoutTimeRemaining = 0
                }
            }
        }

        guard analysis.faceCount > 0, let observation = analysis.observation else {
            consecutiveMatches.removeAll()
            let res = MatchResult.noFace
            DispatchQueue.main.async { self.currentResult = res }
            return res
        }

        guard analysis.isWellPositioned, let queryVector = analysis.vector else {
            consecutiveMatches.removeAll()
            let res = MatchResult.analyzing(guidance: analysis.guidance)
            DispatchQueue.main.async { self.currentResult = res }
            return res
        }

        // Liveness check
        if settings.requireLiveness {
            let liveness = livenessDetector.processFrame(observation: observation)
            switch liveness {
            case .idle:
                let res = MatchResult.livenessRequired(hint: "Looking at camera…")
                DispatchQueue.main.async { self.currentResult = res }
                return res
            case .analyzing(_, let hint):
                let res = MatchResult.livenessRequired(hint: hint)
                DispatchQueue.main.async { self.currentResult = res }
                return res
            case .failed(let reason):
                let res = MatchResult.analyzing(guidance: reason)
                DispatchQueue.main.async { self.currentResult = res }
                return res
            case .passed:
                break // Proceed to matching
            }
        }

        // Search for matching user across enrolled templates
        var bestMatchUser: UserProfile?
        var bestConfidence: Float = 0.0

        for profile in profiles where profile.isEnrolled {
            for template in profile.templates {
                let similarity = queryVector.similarity(to: template.vector)
                if similarity > bestConfidence {
                    bestConfidence = similarity
                    bestMatchUser = profile
                }
            }
        }

        if bestConfidence >= settings.sensitivityThreshold, let matchedUser = bestMatchUser {
            let currentCount = (consecutiveMatches[matchedUser.id] ?? 0) + 1
            consecutiveMatches[matchedUser.id] = currentCount

            if currentCount >= settings.requiredConsecutiveFrames {
                // Verified authentication!
                failedAttempts = 0
                consecutiveMatches.removeAll()
                let res = MatchResult.authenticated(user: matchedUser, confidence: bestConfidence)
                DispatchQueue.main.async {
                    self.currentResult = res
                    ProfileManager.shared.recordAuthentication(for: matchedUser.id)
                }
                return res
            } else {
                let res = MatchResult.analyzing(guidance: "Scanning…")
                DispatchQueue.main.async { self.currentResult = res }
                return res
            }
        } else {
            consecutiveMatches.removeAll()
            // Insufficient similarity
            let res = MatchResult.notRecognized(attempts: failedAttempts)
            DispatchQueue.main.async { self.currentResult = res }
            return res
        }
    }

    public func findBestMatch(for queryVector: FaceGeometryVector, candidates: [UserProfile]) -> (user: UserProfile, confidence: Float)? {
        var bestMatchUser: UserProfile?
        var bestConfidence: Float = 0.0

        for profile in candidates where profile.isEnrolled {
            for template in profile.templates {
                let similarity = queryVector.similarity(to: template.vector)
                if similarity > bestConfidence {
                    bestConfidence = similarity
                    bestMatchUser = profile
                }
            }
        }

        if let user = bestMatchUser, bestConfidence >= settings.sensitivityThreshold {
            return (user, bestConfidence)
        }
        return nil
    }

    public func registerExplicitFailure() {
        lock.lock()
        defer { lock.unlock() }

        failedAttempts += 1
        if failedAttempts >= settings.maxFailedAttempts {
            lockoutEndTime = Date().addingTimeInterval(settings.lockoutDuration)
            DispatchQueue.main.async {
                self.isLockedOut = true
                self.lockoutTimeRemaining = self.settings.lockoutDuration
            }
        }
    }

    /// Fallback to macOS Touch ID or System Password
    public func authenticateWithSystem(reason: String = "Face ID for Mac needs to verify your identity", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, _ in
                DispatchQueue.main.async {
                    if success {
                        self?.lock.lock()
                        self?.failedAttempts = 0
                        self?.lockoutEndTime = nil
                        self?.isLockedOut = false
                        self?.lock.unlock()
                    }
                    completion(success)
                }
            }
        } else {
            completion(false)
        }
    }
}
