import AppKit

public final class TrackpadHapticsManager {
    public static let shared = TrackpadHapticsManager()

    public var isHapticsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "enableTrackpadHaptics") }
        set { UserDefaults.standard.set(newValue, forKey: "enableTrackpadHaptics") }
    }

    public init() {
        if UserDefaults.standard.object(forKey: "enableTrackpadHaptics") == nil {
            UserDefaults.standard.set(true, forKey: "enableTrackpadHaptics")
        }
    }

    /// Deliver a crisp physical Apple tactile click on the trackpad
    public func playSuccess() {
        guard isHapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
    }

    /// Deliver a subtle haptic tap on scanning start or guidance
    public func playSubtle() {
        guard isHapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now
        )
    }
}
