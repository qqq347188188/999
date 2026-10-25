import Foundation

/// 账号本地存储：accounts.json（与 Android/桌面版同格式的 JSON 数组）。
/// 数据仅存于 App 私有目录，卸载即清除，不依赖钥匙串。
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published private(set) var accounts: [Account] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "wb.accounts")

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = dir.appendingPathComponent("accounts.json")
        load()
    }

    // MARK: - 读取 / 落盘

    func load() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let data = try? Data(contentsOf: self.fileURL),
                  let list = try? JSONDecoder().decode([Account].self, from: data) else {
                DispatchQueue.main.async { self.accounts = [] }
                return
            }
            DispatchQueue.main.async { self.accounts = list }
        }
    }

    private func persist(_ list: [Account]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        let tmp = fileURL.deletingLastPathComponent()
            .appendingPathComponent("accounts.json.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
        } catch { }
    }

    // MARK: - 增删改

    func upsert(_ account: Account) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var list = self.accounts
            if let idx = list.firstIndex(where: { $0.id == account.id }) {
                list[idx] = account
            } else {
                list.append(account)
            }
            self.persist(list)
            DispatchQueue.main.async { self.accounts = list }
        }
    }

    /// 按 uid 合并（导入时本地备注/displayField 优先），无匹配则新增。
    func importAccount(_ incoming: Account, fallbackId: String) -> String {
        let id = incoming.id.isEmpty ? fallbackId : incoming.id
        var acc = incoming
        acc.id = id
        queue.sync { [weak self] in
            guard let self = self else { return }
            var list = self.accounts
            if let idx = list.firstIndex(where: { $0.uid == acc.uid && acc.uid?.isEmpty == false }) {
                // 合并：以导入为主，但保留本地 id
                var merged = acc
                merged.id = list[idx].id
                list[idx] = merged
            } else if let idx = list.firstIndex(where: { $0.id == id }) {
                list[idx] = acc
            } else {
                list.append(acc)
            }
            self.persist(list)
            DispatchQueue.main.async { self.accounts = list }
        }
        return id
    }

    func delete(_ id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let list = self.accounts.filter { $0.id != id }
            self.persist(list)
            DispatchQueue.main.async { self.accounts = list }
        }
    }

    func account(id: String) -> Account? {
        accounts.first { $0.id == id }
    }

    // MARK: - 导入 / 导出

    func exportJSON(ids: [String]? = nil) -> String {
        let list = accounts.filter { ids?.contains($0.id) != false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(list)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    func importJSON(_ text: String) -> (imported: Int, overwritten: Int, skipped: Int) {
        guard let data = text.data(using: .utf8),
              let list = try? JSONDecoder().decode([Account].self, from: data) else {
            return (0, 0, 0)
        }
        var imported = 0, overwritten = 0, skipped = 0
        for acc in list {
            if acc.accessToken.isEmpty {
                skipped += 1
                continue
            }
            let had = accounts.contains(where: { $0.uid == acc.uid && !(acc.uid?.isEmpty ?? true) })
            _ = importAccount(acc, fallbackId: UUID().uuidString)
            if had { overwritten += 1 } else { imported += 1 }
        }
        return (imported, overwritten, skipped)
    }
}
