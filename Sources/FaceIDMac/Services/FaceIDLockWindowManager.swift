import AppKit
import SwiftUI

public enum UnlockUIMode: String, CaseIterable {
    case dynamicIsland = "dynamicIsland"
    case fullScreenLock = "fullScreenLock"
}

public final class FaceIDLockWindowManager: ObservableObject {
    public static let shared = FaceIDLockWindowManager()

    private var lockWindow: NSWindow?
    private var notchWindow: NSWindow?
    @Published public var isLockWindowVisible = false

    public var preferredUIMode: UnlockUIMode {
        get {
            let val = UserDefaults.standard.string(forKey: "unlockUIMode") ?? UnlockUIMode.dynamicIsland.rawValue
            return UnlockUIMode(rawValue: val) ?? .dynamicIsland
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "unlockUIMode")
        }
    }

    public init() {
        setupListeners()
    }

    private func setupListeners() {
        NotificationCenter.default.addObserver(
            forName: .userReturnedToMac,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.presentLockOverlay()
        }
    }

    public func presentLockOverlay(targetAppName: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.preferredUIMode == .dynamicIsland {
                self.presentDynamicIslandNotch()
            } else {
                self.presentFullScreenLock()
            }
        }
    }

    public func presentFullScreenLock() {
        if lockWindow == nil {
            createFullScreenLockWindow()
        }

        if let screen = NSScreen.main {
            lockWindow?.setFrame(screen.frame, display: true)
        }

        NSApp.activate(ignoringOtherApps: true)
        lockWindow?.alphaValue = 0
        lockWindow?.makeKeyAndOrderFront(nil)
        isLockWindowVisible = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            self.lockWindow?.animator().alphaValue = 1.0
        }
    }

    public func presentNotchEnrollment() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.createNotchWindow(isEnrollment: true)
            self.displayNotchWindow()
        }
    }

    public func presentDynamicIslandNotch() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.notchWindow == nil {
                self.createNotchWindow(isEnrollment: false)
            }
            self.displayNotchWindow()
        }
    }

    private func displayNotchWindow() {
        guard let screen = NSScreen.screens.first ?? NSScreen.main else { return }

        // Position at the top center right under the notch/camera
        let windowWidth: CGFloat = 380
        let windowHeight: CGFloat = 140
        let xPos = screen.frame.midX - (windowWidth / 2.0)
        let yPos = screen.frame.maxY - windowHeight

        notchWindow?.setFrame(NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight), display: true)
        let maxLevel = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
        notchWindow?.level = maxLevel
        NSApp.activate(ignoringOtherApps: true)
        notchWindow?.orderFrontRegardless()
        notchWindow?.alphaValue = 1.0
        isLockWindowVisible = true
    }

    public func dismissLockOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self.lockWindow?.animator().alphaValue = 0
                self.notchWindow?.animator().alphaValue = 0
            }, completionHandler: {
                self.lockWindow?.orderOut(nil)
                self.notchWindow?.orderOut(nil)
                self.lockWindow?.alphaValue = 1.0
                self.notchWindow?.alphaValue = 1.0
                self.isLockWindowVisible = false
            })
        }
    }

    private func createFullScreenLockWindow() {
        let screenRect = (NSScreen.screens.first ?? NSScreen.main)?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let window = NSWindow(
            contentRect: screenRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = true
        window.backgroundColor = .black
        let maxLevel = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
        window.level = maxLevel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovable = false

        let rootView = MacLockScreenOverlayView(
            onUnlocked: { [weak self] in
                AutoLockManager.shared.unlockWorkspace()
                AppLockerMonitor.shared.unlockAll()
                AudioFeedback.shared.playRecognized()
                TrackpadHapticsManager.shared.playSuccess()
                SystemPasswordUnlocker.shared.typePasswordAndSubmit()
                self?.dismissLockOverlay()
            },
            onDismiss: { [weak self] in
                self?.dismissLockOverlay()
            }
        )

        window.contentView = NSHostingView(rootView: rootView)
        self.lockWindow = window
    }

    private func createNotchWindow(isEnrollment: Bool = false) {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isFloatingPanel = true
        window.isOpaque = false
        window.backgroundColor = .clear
        let maxLevel = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
        window.level = maxLevel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isMovable = false
        window.hasShadow = false
        window.canHide = false
        window.hidesOnDeactivate = false

        let rootView = DynamicIslandNotchView(
            isEnrollment: isEnrollment,
            onUnlocked: { [weak self] in
                AutoLockManager.shared.unlockWorkspace()
                AppLockerMonitor.shared.unlockAll()
                self?.dismissLockOverlay()
            },
            onDismiss: { [weak self] in
                self?.dismissLockOverlay()
            }
        )

        window.contentView = NSHostingView(rootView: rootView)
        self.notchWindow = window
    }
}
