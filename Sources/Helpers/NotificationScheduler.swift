import Foundation
import BackgroundTasks
import UserNotifications

/// 本地通知（每日提醒打开 App 签到）与 BGTask 后台刷新调度。
final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private let reminderID = "wb.daily.reminder"

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleDailyReminderIfNeeded() {
        let center = UNUserNotificationCenter.current()
        guard AppConfig.notificationsEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
            return
        }
        requestAuthorization()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        var comps = DateComponents()
        comps.hour = AppConfig.checkinHour
        comps.minute = AppConfig.checkinMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "WB签到"
        content.body = "到点啦，打开 App 完成今日签到 / 派猫猫旅行吧～"
        content.sound = .default
        let req = UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger)
        center.add(req)
    }

    func scheduleAppRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: "com.wbcheckin.refresh")
        req.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }
}
