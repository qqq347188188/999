import Foundation

struct LogEntry: Codable, Identifiable {
    var id: String
    var date: Int          // 纪元秒
    var accountId: String
    var accountName: String
    var type: String       // checkin / travel / refresh / system / error
    var ok: Bool
    var message: String

    init(id: String = UUID().uuidString,
         date: Int = Int(Date().timeIntervalSince1970),
         accountId: String,
         accountName: String,
         type: String,
         ok: Bool,
         message: String) {
        self.id = id
        self.date = date
        self.accountId = accountId
        self.accountName = accountName
        self.type = type
        self.ok = ok
        self.message = message
    }
}
