import Foundation
@preconcurrency import UserNotifications

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private struct NotificationPayload: Sendable {
        let title: String
        let subtitle: String
        let body: String
        let playSound: Bool
    }

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        completion?(granted)
                    }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    completion?(true)
                }
            default:
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }

    /// Shown on first launch only, so later launches stay quiet.
    func showAppReady(shortcut: String) {
        let body = ScreenCaptureAccess.hasWorkingAccess()
            ? "Press \(shortcut) or use the menu bar icon to capture text from the screen."
            : "Press \(shortcut) to capture. macOS will ask for Screen Recording the first time."
        deliver(
            NotificationPayload(
                title: "ScreenOCR is running",
                subtitle: "Menu bar app · ready to capture text",
                body: body,
                playSound: false
            )
        )
    }

    /// Shown when the user finishes the welcome window.
    func showWelcomeCompleted(shortcut: String) {
        deliver(
            NotificationPayload(
                title: "You're all set",
                subtitle: "ScreenOCR",
                body: "Capture anytime with \(shortcut). Reopen tips from the menu bar → Getting Started…",
                playSound: true
            )
        )
    }

    func showError(title: String, body: String) {
        deliver(
            NotificationPayload(
                title: title,
                subtitle: "ScreenOCR",
                body: body,
                playSound: true
            )
        )
    }

    private func deliver(_ payload: NotificationPayload) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = payload.title
            content.subtitle = payload.subtitle
            content.body = payload.body
            if payload.playSound {
                content.sound = .default
            }

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.35, repeats: false)
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
