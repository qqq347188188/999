import SwiftUI
import UIKit
import BackgroundTasks
import UserNotifications

@main
struct WBApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.wbcheckin.refresh",
            using: nil
        ) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
        NotificationScheduler.shared.scheduleDailyReminderIfNeeded()
        NotificationScheduler.shared.scheduleAppRefresh()
        Task { await Bootstrap.launchCheckinIfNeeded() }
        return true
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        Task {
            await Bootstrap.runBackgroundCycle()
            task.setTaskCompleted(success: true)
        }
        NotificationScheduler.shared.scheduleAppRefresh()
    }
}
