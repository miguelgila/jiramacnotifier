import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            if granted {
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        }
    }

    func sendNotification(for issue: JiraIssue, instanceName: String, filterName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(instanceName) - \(filterName)"
        content.body = "\(issue.key): \(issue.fields.summary)"
        content.subtitle = "Status: \(issue.fields.status.name)"
        content.sound = .default

        // Add actions
        let openAction = UNNotificationAction(
            identifier: "OPEN_ACTION",
            title: "Open in Browser",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: "JIRA_ISSUE",
            actions: [openAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "JIRA_ISSUE"

        // Store issue key in userInfo for later use
        content.userInfo = ["issueKey": issue.key]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Send immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
