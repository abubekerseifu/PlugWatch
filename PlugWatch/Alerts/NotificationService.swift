import Foundation
import UserNotifications

enum NotificationActionID {
    static let category = "BATTERY_UNPLUGGED"
    static let dismiss = "DISMISS"
    static let snooze = "SNOOZE_30"
}

@MainActor
protocol NotificationActionHandling: AnyObject {
    func handleNotificationDismiss()
    func handleNotificationSnooze()
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    weak var actionHandler: NotificationActionHandling?

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let dismiss = UNNotificationAction(
            identifier: NotificationActionID.dismiss,
            title: "Dismiss",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationActionID.snooze,
            title: "Snooze (30 min)",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationActionID.category,
            actions: [dismiss, snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postUnpluggedAlert() {
        let content = UNMutableNotificationContent()
        content.title = "Still on Battery"
        content.body = "Your Mac has been unplugged for a while. Plug in to protect battery habits."
        content.sound = .default
        content.categoryIdentifier = NotificationActionID.category

        let request = UNNotificationRequest(
            identifier: "plugwatch.unplugged.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func removeDeliveredAlerts() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let handler = actionHandler
        switch response.actionIdentifier {
        case NotificationActionID.dismiss:
            await MainActor.run { handler?.handleNotificationDismiss() }
        case NotificationActionID.snooze:
            await MainActor.run { handler?.handleNotificationSnooze() }
        case UNNotificationDefaultActionIdentifier:
            break
        default:
            break
        }
    }
}
