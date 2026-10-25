import Foundation

/// 全局设置（基于 UserDefaults）。UI 中可直接用 @AppStorage 绑定同一组 key。
enum AppConfig {
    static let autoCheckinKey      = "autoCheckin"
    static let autoTravelKey       = "autoTravel"
    static let keepTokenAliveKey   = "keepTokenAlive"
    static let notificationsKey    = "notificationsEnabled"
    static let checkinHourKey      = "checkinHour"
    static let checkinMinuteKey    = "checkinMinute"
    static let lastAutoCheckinKey  = "lastAutoCheckinDate"
    static let lastKeepAliveKey    = "lastKeepAliveDate"

    static func bool(_ key: String, default def: Bool = false) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return def }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func setBool(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func int(_ key: String, default def: Int) -> Int {
        if let v = UserDefaults.standard.object(forKey: key) as? Int { return v }
        return def
    }

    static func setInt(_ key: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func string(_ key: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? ""
    }

    static func setString(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    /// 当天日期串 yyyy-MM-dd，用于“每日只自动签到一次”的判断。
    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f.string(from: Date())
    }

    static var autoCheckin: Bool { bool(autoCheckinKey, default: true) }
    static var autoTravel: Bool { bool(autoTravelKey) }
    static var keepTokenAlive: Bool { bool(keepTokenAliveKey, default: true) }
    static var notificationsEnabled: Bool { bool(notificationsKey) }
    static var checkinHour: Int { int(checkinHourKey, default: 9) }
    static var checkinMinute: Int { int(checkinMinuteKey, default: 0) }
}
