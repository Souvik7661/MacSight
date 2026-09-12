import AppKit
import Combine

public final class AutoLockManager: ObservableObject {
    public static let shared = AutoLockManager()

    @Published public var isAutoLockEnabled: Bool = true
    @Published public var lockTimeoutMinutes: Int = 5 // 1, 5, 15, 30
    @Published public var isWorkspaceLocked: Bool = false

    private var observers: [NSObjectProtocol] = []
    private var idleCheckTimer: Timer?

    public init() {
        setupSystemObservers()
        startIdleMonitoring()
    }

    deinit {
        stopSystemObservers()
        idleCheckTimer?.invalidate()
    }

    private func setupSystemObservers() {
        let center = NSWorkspace.shared.notificationCenter

        // Screen sleep -> lock
        observers.append(center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenSleep()
        })

        // Screen wake -> return detection
        observers.append(center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenWake()
        })

        // User fast switch / lock screen
        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSessionResign()
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenWake()
        })
    }

    private func stopSystemObservers() {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        observers.removeAll()
    }

    private func startIdleMonitoring() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkUserIdleTime()
        }
    }

    private func checkUserIdleTime() {
        guard isAutoLockEnabled, !isWorkspaceLocked, lockTimeoutMinutes > 0 else { return }

        // Check system idle time using CGEventSource
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)

        let timeoutSeconds = Double(lockTimeoutMinutes * 60)
        if idleSeconds >= timeoutSeconds {
            lockWorkspace()
        }
    }

    public func lockWorkspace() {
        isWorkspaceLocked = true
        AppLockerMonitor.shared.lockAll()
        NotificationManager.shared.postNotification(
            title: "Face ID for Mac",
            body: "Protected workspace locked."
        )
        FaceIDLockWindowManager.shared.presentLockOverlay()
    }

    public func unlockWorkspace() {
        isWorkspaceLocked = false
        AppLockerMonitor.shared.unlockAll()
        AudioFeedback.shared.playRecognized()
        FaceIDLockWindowManager.shared.dismissLockOverlay()
    }

    private func handleScreenSleep() {
        if isAutoLockEnabled {
            isWorkspaceLocked = true
            AppLockerMonitor.shared.lockAll()
        }
    }

    private func handleSessionResign() {
        if isAutoLockEnabled {
            isWorkspaceLocked = true
            AppLockerMonitor.shared.lockAll()
        }
    }

    private func handleScreenWake() {
        // User returned to Mac / Screen woke up!
        if ProfileManager.shared.isAnyUserEnrolled {
            isWorkspaceLocked = true
            NotificationCenter.default.post(name: .userReturnedToMac, object: nil)
            FaceIDLockWindowManager.shared.presentLockOverlay()
        }
    }
}

public extension Notification.Name {
    static let userReturnedToMac = Notification.Name("com.faceidformac.userReturnedToMac")
}
