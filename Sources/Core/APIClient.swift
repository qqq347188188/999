import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case routeMissing
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "服务器返回格式异常"
        case .routeMissing:    return "接口路径不存在（请检查账号区域）"
        case .network(let e):  return "网络错误：\(e.localizedDescription)"
        }
    }
}

struct CheckinResult {
    let account: Account
    let status: Status
    let message: String
    enum Status { case success, already, error, skipped }
}

/// 对接 WorkBuddy / CodeBuddy 后台的协议封装层，严格模拟桌面客户端请求特征。
final class APIClient {
    static let shared = APIClient()

    // 必须与桌面版一致，否则网关会拦截。
    private static let ua =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36"

    private init() {}

    // MARK: - 端点解析

    static func endpoint(for variant: String, domain: String?) -> String {
        let dom = domain ?? ""
        if variant == "ai" { return "https://www.workbuddy.ai" }
        return dom.contains("workbuddy") ? "https://www.workbuddy.cn" : "https://www.codebuddy.cn"
    }

    /// 派猫猫旅行接口固定在 workbuddy.cn（/activity/growth/... 无 /v2 前缀）。
    static func travelEndpoint(for variant: String) -> String {
        variant == "ai" ? "https://www.workbuddy.ai" : "https://www.workbuddy.cn"
    }

    // MARK: - 请求头

    private static func baseHeaders() -> [String: String] {
        ["User-Agent": ua, "Content-Type": "application/json", "Accept": "application/json"]
    }

    private static func authHeaders(account: Account) -> [String: String] {
        var h = baseHeaders()
        h["Authorization"] = "Bearer \(account.accessToken)"
        if let uid = account.uid, !uid.isEmpty { h["X-User-Id"] = uid }
        if let eid = account.enterpriseId, !eid.isEmpty {
            h["X-Enterprise-Id"] = eid
            h["X-Tenant-Id"] = eid
        }
        if let domain = account.domain, !domain.isEmpty { h["X-Domain"] = domain }
        return h
    }

    private static func resourceHeaders(account: Account) -> [String: String] {
        var h = authHeaders(account: account)
        h["X-Client-Platform"] = "web"
        let origin = endpoint(for: account.variant, domain: account.domain)
        h["Origin"] = origin
        h["Referer"] = "\(origin)/profile/plans-usage"
        return h
    }

    // MARK: - 底层请求

    private static func request(url: URL, method: String,
                                headers: [String: String],
                                body: [String: Any]?) async throws -> (json: [String: Any], status: Int) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        for (k, v) in headers where !k.isEmpty { req.setValue(v, forHTTPHeaderField: k) }
        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        var json: [String: Any] = [:]
        if let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { json = d }
        return (json, status)
    }

    /// 依次尝试候选路径，遇到 404 换下一个；返回首个 2xx 的 JSON。
    private static func postFirstOk(base: String, candidates: [String],
                                    headers: [String: String],
                                    body: [String: Any]) async throws -> [String: Any] {
        var lastError: Error = APIError.routeMissing
        for path in candidates {
            guard let url = URL(string: base + path) else { continue }
            do {
                let (json, status) = try await request(url: url, method: "POST", headers: headers, body: body)
                if status == 404 { lastError = APIError.routeMissing; continue }
                return json
            } catch { lastError = error }
        }
        throw lastError
    }

    private static func post(url: URL, headers: [String: String], body: [String: Any]) async throws -> [String: Any] {
        let (json, _) = try await request(url: url, method: "POST", headers: headers, body: body)
        return json
    }

    private static func get(url: URL, headers: [String: String]) async throws -> [String: Any] {
        let (json, _) = try await request(url: url, method: "GET", headers: headers, body: nil)
        return json
    }

    // MARK: - 响应判定

    private static func codeOk(_ json: [String: Any]) -> Bool {
        let code = json["code"] as? Int
        return code == 0 || code == 200
    }

    private static func firstMessage(_ json: [String: Any]) -> String {
        if let m = json["msg"] as? String { return m }
        if let m = json["message"] as? String { return m }
        if let d = json["data"] as? [String: Any], let m = d["msg"] as? String { return m }
        return ""
    }

    private static func isUnauthorized(_ json: [String: Any]) -> Bool {
        let code = json["code"] as? Int
        return code == 401 || code == 403
    }

    // MARK: - OAuth 登录

    static func oauthStart(variant: String) async throws -> (state: String, authUrl: String) {
        let ep = endpoint(for: variant, domain: nil)
        let platform = variant == "ai" ? "workbuddy-ai" : "workbuddy"
        guard let url = URL(string: "\(ep)/v2/plugin/auth/state?platform=\(platform)") else {
            throw APIError.invalidResponse
        }
        let json = try await post(url: url, headers: baseHeaders(), body: [:])
        let data = json["data"] as? [String: Any] ?? json
        guard let state = data["state"] as? String,
              let authUrl = data["authUrl"] as? String else {
            throw APIError.invalidResponse
        }
        return (state, authUrl)
    }

    /// 轮询令牌；未就绪返回 nil。
    static func oauthPollToken(variant: String, state: String) async throws -> [String: Any]? {
        let ep = endpoint(for: variant, domain: nil)
        guard let url = URL(string: "\(ep)/v2/plugin/auth/token?state=\(state)") else { return nil }
        let json = try await get(url: url, headers: baseHeaders())
        guard codeOk(json) else { return nil }
        let data = json["data"] as? [String: Any] ?? json
        if let at = data["accessToken"] as? String, !at.isEmpty { return data }
        return nil
    }

    static func fetchAccountProfile(variant: String, state: String,
                                    accessToken: String, domain: String?) async throws -> [String: Any] {
        let ep = endpoint(for: variant, domain: domain)
        guard let url = URL(string: "\(ep)/v2/plugin/login/account?state=\(state)") else {
            throw APIError.invalidResponse
        }
        var h = baseHeaders()
        h["Authorization"] = "Bearer \(accessToken)"
        if let domain = domain, !domain.isEmpty { h["X-Domain"] = domain }
        return try await get(url: url, headers: h)
    }

    // MARK: - Token 刷新

    @discardableResult
    static func refreshToken(_ account: inout Account) async -> Bool {
        guard !account.refreshToken.isEmpty else { return false }
        let ep = endpoint(for: account.variant, domain: account.domain)
        guard let url = URL(string: "\(ep)/v2/plugin/auth/token/refresh") else { return false }
        var h = baseHeaders()
        h["X-Refresh-Token"] = account.refreshToken
        h["X-Auth-Refresh-Source"] = "plugin"
        do {
            let json = try await post(url: url, headers: h, body: [:])
            guard codeOk(json) else { return false }
            let d = json["data"] as? [String: Any] ?? json
            guard let at = d["accessToken"] as? String, !at.isEmpty else { return false }
            account.accessToken = at
            if let rt = d["refreshToken"] as? String, !rt.isEmpty { account.refreshToken = rt }
            if let exp = d["expiresAt"] as? Int { account.expiresAt = exp }
            if let rexp = d["refreshExpiresAt"] as? Int { account.refreshExpiresAt = rexp }
            if let t = d["tokenType"] as? String { account.tokenType = t }
            AccountStore.shared.upsert(account)
            return true
        } catch { return false }
    }

    /// 距过期不足 24h 或已过期时惰性刷新。
    static func ensureFreshToken(_ account: inout Account) async -> Bool {
        let now = Int(Date().timeIntervalSince1970)
        let need = (account.expiresAt ?? 0) - now < 24 * 3600
        if need {
            return await refreshToken(&account)
        }
        return true
    }

    // MARK: - 每日签到

    static func dailyCheckin(_ account: Account) async -> CheckinResult {
        var acc = account
        _ = await ensureFreshToken(&acc)
        let ep = endpoint(for: acc.variant, domain: acc.domain)
        let candidates = acc.variant == "ai"
            ? ["/billing/meter/daily-checkin"]
            : ["/v2/billing/meter/daily-checkin", "/billing/meter/daily-checkin"]

        do {
            let json = try await postFirstOk(base: ep, candidates: candidates,
                                            headers: authHeaders(account: acc), body: [:])
            if codeOk(json) {
                return CheckinResult(account: acc, status: .success, message: "签到成功")
            }
            let msg = firstMessage(json)
            if msg.localizedCaseInsensitiveContains("已签到")
                || msg.localizedCaseInsensitiveContains("repeat") {
                return CheckinResult(account: acc, status: .already, message: "今日已签到")
            }
            if isUnauthorized(json) {
                if await refreshToken(&acc),
                   let json2 = try? await postFirstOk(base: ep, candidates: candidates,
                                                     headers: authHeaders(account: acc), body: [:]) {
                    if codeOk(json2) {
                        return CheckinResult(account: acc, status: .success, message: "签到成功（刷新后）")
                    }
                    let m2 = firstMessage(json2)
                    if m2.localizedCaseInsensitiveContains("已签到") {
                        return CheckinResult(account: acc, status: .already, message: "今日已签到")
                    }
                }
                return CheckinResult(account: acc, status: .error, message: "登录失效，请重新登录")
            }
            return CheckinResult(account: acc, status: .error,
                                message: msg.isEmpty ? "签到失败" : msg)
        } catch {
            return CheckinResult(account: acc, status: .error, message: error.localizedDescription)
        }
    }

    static func checkinStatus(_ account: Account) async
        -> (todayCheckedIn: Bool, streakDays: Int?, raw: [String: Any]?) {
        let ep = endpoint(for: account.variant, domain: account.domain)
        let candidates = account.variant == "ai"
            ? ["/billing/meter/checkin-activity-status", "/billing/meter/checkin-status"]
            : ["/v2/billing/meter/checkin-activity-status",
               "/v2/billing/meter/checkin-status",
               "/billing/meter/checkin-activity-status"]
        do {
            let json = try await postFirstOk(base: ep, candidates: candidates,
                                            headers: authHeaders(account: account), body: [:])
            let d = json["data"] as? [String: Any] ?? json
            let tci = d["today_checked_in"] as? Bool ?? d["todayCheckedIn"] as? Bool ?? false
            let streak = d["streak_days"] as? Int ?? d["streakDays"] as? Int
            return (tci, streak, d)
        } catch {
            return (false, nil, nil)
        }
    }

    // MARK: - 额度 / 资源

    static func resourceSummary(_ account: Account) async -> [String: Any]? {
        let ep = endpoint(for: account.variant, domain: account.domain)
        let candidates = account.variant == "ai"
            ? ["/billing/meter/get-user-resource-summary"]
            : ["/v2/billing/meter/get-user-resource-summary",
               "/billing/meter/get-user-resource-summary"]
        do {
            return try await postFirstOk(base: ep, candidates: candidates,
                                        headers: resourceHeaders(account: account), body: [:])
        } catch { return nil }
    }

    // MARK: - 派猫猫旅行

    static func travelStatus(_ account: Account) async -> [String: Any]? {
        let ep = travelEndpoint(for: account.variant)
        guard let url = URL(string: "\(ep)/activity/growth/buddy/travel/status") else { return nil }
        return try? await get(url: url, headers: authHeaders(account: account))
    }

    static func travelConfig(_ account: Account) async -> [String: Any]? {
        let ep = travelEndpoint(for: account.variant)
        guard let url = URL(string: "\(ep)/activity/growth/buddy/travel/config") else { return nil }
        return try? await get(url: url, headers: authHeaders(account: account))
    }

    static func travelDepart(_ account: Account, locationId: Int) async -> [String: Any]? {
        let ep = travelEndpoint(for: account.variant)
        guard let url = URL(string: "\(ep)/activity/growth/buddy/travel/depart") else { return nil }
        return try? await post(url: url, headers: authHeaders(account: account), body: ["location_id": locationId])
    }

    static func travelClaim(_ account: Account) async -> [String: Any]? {
        let ep = travelEndpoint(for: account.variant)
        guard let url = URL(string: "\(ep)/activity/growth/buddy/travel/claim") else { return nil }
        return try? await post(url: url, headers: authHeaders(account: account), body: [:])
    }
}
