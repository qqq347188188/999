import SwiftUI

struct SettingsView: View {
    @AppStorage(AppConfig.autoCheckinKey) private var autoCheckin = true
    @AppStorage(AppConfig.autoTravelKey) private var autoTravel = false
    @AppStorage(AppConfig.keepTokenAliveKey) private var keepTokenAlive = true
    @AppStorage(AppConfig.notificationsKey) private var notifications = false
    @AppStorage(AppConfig.checkinHourKey) private var hour = 9
    @AppStorage(AppConfig.checkinMinuteKey) private var minute = 0
    @State private var showHelp = false

    var body: some View {
        NavigationView {
            Form {
                Section("自动任务") {
                    Toggle("打开 App 自动补签", isOn: $autoCheckin)
                    Toggle("自动派猫猫旅行", isOn: $autoTravel)
                    Toggle("每日令牌保活", isOn: $keepTokenAlive)
                    Toggle("签到提醒通知", isOn: $notifications)
                    Stepper("提醒时间 \(String(format: "%02d:%02d", hour, minute))",
                            value: $hour, in: 0...23)
                    Stepper("提醒分钟 \(minute)", value: $minute, in: 0...59)
                }
                Section("关于") {
                    Button("使用说明 / 隐私协议") { showHelp = true }
                    Text("WB签到 v1.0.0 · 适配 iOS 16.6 (TrollStore)")
                        .font(.caption).foregroundColor(.secondary)
                    Text("数据仅存于本机私有目录，卸载即清除，不收集任何个人信息，无后台服务器。")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .onChange(of: notifications) { _ in NotificationScheduler.shared.scheduleDailyReminderIfNeeded() }
            .onChange(of: hour) { _ in NotificationScheduler.shared.scheduleDailyReminderIfNeeded() }
            .onChange(of: minute) { _ in NotificationScheduler.shared.scheduleDailyReminderIfNeeded() }
            .sheet(isPresented: $showHelp) { HelpView() }
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用说明").font(.headline)
                    Text("1. 在「账号」页添加 WorkBuddy / CodeBuddy 账号：选择区域后点击开始登录，在弹出的网页完成授权，再点「检测登录」即可保存。\n\n2. 在「签到」页点击「一键签到」为全部账号签到；开启「打开 App 自动补签」后，每天首次启动会自动补签。\n\n3. 「额度」页可查询各账号的资源 / 积分余额。\n\n4. 「派猫猫旅行」按状态机幂等执行：空闲派发、到达领取、旅行中或已达上限则跳过。\n\n5. 账号数据可导出 / 导入，与 Android 版、桌面版 accounts.json 互通。")
                        .font(.footnote)

                    Text("隐私协议").font(.headline)
                    Text("本应用为零收集设计：无注册、无统计 / 广告 SDK、无自有服务器。账号令牌仅存于应用私有目录，卸载即清除；网络请求仅发往官方域名（codebuddy.cn / workbuddy.cn / workbuddy.ai）。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("说明 / 隐私")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
