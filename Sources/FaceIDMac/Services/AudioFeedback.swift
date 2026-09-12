import AppKit

public final class AudioFeedback: @unchecked Sendable {
    public static let shared = AudioFeedback()

    public var isEnabled: Bool = true

    public func playRecognized() {
        guard isEnabled else { return }
        // Subtle affirmative Apple sound
        NSSound(named: "Glass")?.play()
    }

    public func playFailure() {
        guard isEnabled else { return }
        NSSound(named: "Basso")?.play()
    }

    public func playLock() {
        guard isEnabled else { return }
        NSSound(named: "Pop")?.play()
    }

    public func playScanStart() {
        guard isEnabled else { return }
        NSSound(named: "Tink")?.play()
    }
}
