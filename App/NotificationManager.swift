import UserNotifications

/// System notifications with a "Skip" button while resting.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    /// Called on the main thread when "Skip" is pressed on a notification.
    var onSkip: (@MainActor () -> Void)?

    private enum Category { static let restStarted = "restStarted"; static let restEnded = "restEnded" }
    private enum Action { static let skip = "skipRest" }

    override init() {
        super.init()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, _ in }
        let skip = UNNotificationAction(identifier: Action.skip, title: String(localized: "Skip"), options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.restStarted, actions: [skip], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.restEnded, actions: [], intentIdentifiers: []),
        ])
    }

    func restStarted(long: Bool) {
        send(title: String(localized: "Time's up"),
             body: long ? String(localized: "It's time for a long break!") : String(localized: "It's time for a short break!"),
             category: Category.restStarted)
    }

    func restEnded() {
        send(title: String(localized: "Break is over"), body: String(localized: "Keep up the good work!"),
             category: Category.restEnded)
    }

    private func send(title: String, body: String, category: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        completionHandler()
        if action == Action.skip { Task { @MainActor in self.onSkip?() } }
    }

    /// Show banners even while BreakBar is the active app.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
