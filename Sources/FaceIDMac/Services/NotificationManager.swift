import Foundation
import UserNotifications

public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()

    @Published public var isNotificationsEnabled: Bool = true

    public init() {
        requestAuthorization()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = granted
            }
        }
    }

    public func postNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        guard isNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
