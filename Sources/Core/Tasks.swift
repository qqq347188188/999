import Foundation

/// 启动与后台周期的编排逻辑。
struct Bootstrap {
    /// App 启动：开启自动签到且今日尚未执行时跑一次。
    static func launchCheckinIfNeeded() async {
        guard AppConfig.autoCheckin else { return }
        if AppConfig.string(AppConfig.lastAutoCheckinKey) == AppConfig.todayString() { return }
        await runDailyCycle()
        AppConfig.setString(AppConfig.lastAutoCheckinKey, AppConfig.todayString())
    }

    /// 后台刷新周期：签到 +（可选）旅行 +（可选）令牌保活。
    static func runBackgroundCycle() async {
        await runDailyCycle()
        if AppConfig.keepTokenAlive {
            await keepAlive()
            AppConfig.setString(AppConfig.lastKeepAliveKey, AppConfig.todayString())
        }
    }

    static func runDailyCycle() async {
        let results = await CheckinTasks.runDailyCheckin(autoTravel: AppConfig.autoTravel)
        for r in results {
            let ok = r.status == .success || r.status == .already
            Logger.shared.add(type: "checkin", account: r.account, ok: ok, message: r.message)
        }
    }

    static func keepAlive() async {
        for acc in AccountStore.shared.accounts {
            var a = acc
            let ok = await APIClient.ensureFreshToken(&a)
            Logger.shared.add(type: "refresh", account: a, ok: ok,
                              message: ok ? "令牌保活成功" : "令牌保活失败")
        }
    }
}

/// 签到与派猫猫旅行的具体执行。
struct CheckinTasks {
    static func runDailyCheckin(autoTravel: Bool) async -> [CheckinResult] {
        var results: [CheckinResult] = []
        let accounts = AccountStore.shared.accounts
        for acc in accounts {
            let r = await APIClient.dailyCheckin(acc)
            results.append(r)
            if autoTravel && r.status != .error {
                let t = await travelCycle(acc)
                Logger.shared.add(type: "travel", account: acc, ok: t.ok, message: t.message)
            }
        }
        return results
    }

    /// 派猫猫旅行状态机：idle→派发；arrived→领取；traveling / daily_limit_reached→跳过。
    static func travelCycle(_ account: Account) async -> (ok: Bool, message: String) {
        guard let status = await APIClient.travelStatus(account) else {
            return (false, "旅行状态获取失败")
        }
        let data = status["data"] as? [String: Any] ?? status
        let state = (data["state"] as? String ?? "").lowercased()
        switch state {
        case "arrived":
            let claim = await APIClient.travelClaim(account)
            let ok = (claim?["code"] as? Int).map { $0 == 0 || $0 == 200 } ?? false
            return (ok, ok ? "领取积分成功" : "领取失败：\(claim?["msg"] ?? "未知")")
        case "idle":
            guard let cfg = await APIClient.travelConfig(account),
                  let cfgData = cfg["data"] as? [String: Any],
                  let list = (cfgData["list"] as? [[String: Any]]) ?? (cfgData["locations"] as? [[String: Any]]),
                  let loc = list.randomElement(),
                  let lid = (loc["id"] as? Int) ?? (loc["location_id"] as? Int) else {
                return (false, "无可用地点")
            }
            let dep = await APIClient.travelDepart(account, locationId: lid)
            let ok = (dep?["code"] as? Int).map { $0 == 0 || $0 == 200 } ?? false
            return (ok, ok ? "已派出旅行，到达后可领取" : "派发失败：\(dep?["msg"] ?? "未知")")
        case "traveling":
            return (true, "旅行中，尚未到达")
        case "daily_limit_reached":
            return (true, "今日已达上限")
        default:
            return (false, "未知状态：\(state)")
        }
    }
}
