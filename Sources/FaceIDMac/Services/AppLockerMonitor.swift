import AppKit
import Combine

public struct ProtectedAppItem: Identifiable, Codable, Hashable {
    public var id: String // bundle identifier
    public var name: String
    public var isProtected: Bool

    public init(id: String, name: String, isProtected: Bool = true) {
        self.id = id
        self.name = name
        self.isProtected = isProtected
    }
}

public final class AppLockerMonitor: ObservableObject {
    public static let shared = AppLockerMonitor()

    @Published public var protectedApps: [ProtectedAppItem] = []
    @Published public var isMonitoringEnabled: Bool = true
    @Published public var currentlyLockedApp: ProtectedAppItem?
    @Published public var showLockScreen: Bool = false

    private var unlockedSessions: Set<String> = []
    private var observer: NSObjectProtocol?
    private let userDefaultsKey = "FaceIDMac_ProtectedApps"

    public init() {
        loadProtectedApps()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func loadProtectedApps() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let items = try? JSONDecoder().decode([ProtectedAppItem].self, from: data) {
            self.protectedApps = items
        } else {
            // Default suggested apps to protect
            self.protectedApps = [
                ProtectedAppItem(id: "com.apple.Notes", name: "Notes", isProtected: true),
                ProtectedAppItem(id: "com.apple.Photos", name: "Photos", isProtected: true),
                ProtectedAppItem(id: "com.apple.mail", name: "Mail", isProtected: true),
                ProtectedAppItem(id: "com.apple.MobileSMS", name: "Messages", isProtected: false),
                ProtectedAppItem(id: "com.apple.Safari", name: "Safari", isProtected: false),
                ProtectedAppItem(id: "com.apple.systempreferences", name: "System Settings", isProtected: false)
            ]
            save()
        }
    }

    public func save() {
        if let data = try? JSONEncoder().encode(protectedApps) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    public func toggleApp(id: String) {
        if let idx = protectedApps.firstIndex(where: { $0.id == id }) {
            protectedApps[idx].isProtected.toggle()
            save()
        }
    }

    public func addCustomApp(url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return }

        let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String) ??
                   (bundle.infoDictionary?["CFBundleName"] as? String) ??
                   url.deletingPathExtension().lastPathComponent

        if !protectedApps.contains(where: { $0.id == bundleId }) {
            protectedApps.append(ProtectedAppItem(id: bundleId, name: name, isProtected: true))
            save()
        }
    }

    public func removeApp(id: String) {
        protectedApps.removeAll(where: { $0.id == id })
        save()
    }

    public func startMonitoring() {
        guard observer == nil else { return }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }

    public func stopMonitoring() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            observer = nil
        }
    }

    public func unlockSession(bundleId: String) {
        unlockedSessions.insert(bundleId)
        if currentlyLockedApp?.id == bundleId {
            currentlyLockedApp = nil
            showLockScreen = false
        }
    }

    public func unlockAll() {
        for app in protectedApps where app.isProtected {
            unlockedSessions.insert(app.id)
        }
        currentlyLockedApp = nil
        showLockScreen = false
    }

    public func lockAll() {
        unlockedSessions.removeAll()
        AudioFeedback.shared.playLock()
    }

    private func handleAppActivation(_ notification: Notification) {
        guard isMonitoringEnabled else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }

        // Ignore our own app
        if bundleId == Bundle.main.bundleIdentifier { return }

        // Check if app is protected
        if let protectedItem = protectedApps.first(where: { $0.id == bundleId && $0.isProtected }) {
            if !unlockedSessions.contains(bundleId) {
                // Trigger Face ID Lock
                self.currentlyLockedApp = protectedItem
                self.showLockScreen = true
            }
        }
    }
}
