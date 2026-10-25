import Foundation

/// 账号模型，字段命名与 Android 版 accounts.json 保持一致以便互通导入/导出。
struct Account: Codable, Identifiable, Equatable {
    var id: String
    var uid: String?
    var nickname: String?
    var email: String?
    var enterpriseName: String?
    var enterpriseId: String?
    var accessToken: String
    var refreshToken: String
    var tokenType: String?
    var domain: String?
    /// "cn"（国内版 CodeBuddy/WorkBuddy）或 "ai"（国际版 WorkBuddy AI）
    var variant: String
    /// 过期时间戳（秒）
    var expiresAt: Int?
    var refreshExpiresAt: Int?
    var authRaw: String?
    var createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id, uid, nickname, email, enterpriseName, enterpriseId
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case domain, variant, expiresAt, refreshExpiresAt
        case authRaw = "auth_raw"
        case createdAt
    }

    var displayName: String {
        if let n = nickname, !n.isEmpty { return n }
        if let e = email, !e.isEmpty { return e }
        if let u = uid, !u.isEmpty { return u }
        return "账号 " + String(id.prefix(6))
    }

    var variantLabel: String { variant == "ai" ? "国际版" : "国内版" }

    init(id: String, uid: String? = nil, nickname: String? = nil, email: String? = nil,
         enterpriseName: String? = nil, enterpriseId: String? = nil,
         accessToken: String, refreshToken: String, tokenType: String? = nil,
         domain: String? = nil, variant: String, expiresAt: Int? = nil,
         refreshExpiresAt: Int? = nil, authRaw: String? = nil, createdAt: Int) {
        self.id = id
        self.uid = uid
        self.nickname = nickname
        self.email = email
        self.enterpriseName = enterpriseName
        self.enterpriseId = enterpriseId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.domain = domain
        self.variant = variant
        self.expiresAt = expiresAt
        self.refreshExpiresAt = refreshExpiresAt
        self.authRaw = authRaw
        self.createdAt = createdAt
    }
}
