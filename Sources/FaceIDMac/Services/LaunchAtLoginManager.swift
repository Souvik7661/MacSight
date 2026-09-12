import Foundation
import ServiceManagement

public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()

    @Published public var isEnabled: Bool = false

    public init() {
        checkStatus()
    }

    public func checkStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            self.isEnabled = (status == .enabled)
        }
    }

    public func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                self.isEnabled = enabled
            } catch {
                self.isEnabled = false
            }
        }
    }
}
