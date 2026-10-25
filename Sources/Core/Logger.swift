import Foundation

/// 签到/旅行/刷新等运行日志，落盘到 checkin_logs.json，最多保留 500 条。
final class Logger: ObservableObject {
    static let shared = Logger()

    @Published private(set) var logs: [LogEntry] = []

    private let fileURL: URL
    private let maxLogs = 500
    private let queue = DispatchQueue(label: "wb.logger")

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = dir.appendingPathComponent("checkin_logs.json")
        load()
    }

    func add(type: String, account: Account? = nil, ok: Bool, message: String) {
        let entry = LogEntry(
            accountId: account?.id ?? "-",
            accountName: account?.displayName ?? "系统",
            type: type,
            ok: ok,
            message: message
        )
        queue.async { [weak self] in
            guard let self = self else { return }
            var list = self.logs
            list.insert(entry, at: 0)
            if list.count > self.maxLogs { list.removeLast(list.count - self.maxLogs) }
            self.persist(list)
            DispatchQueue.main.async { self.logs = list }
        }
    }

    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.persist([])
            DispatchQueue.main.async { self.logs = [] }
        }
    }

    private func load() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let data = try? Data(contentsOf: self.fileURL),
                  let list = try? JSONDecoder().decode([LogEntry].self, from: data) else { return }
            DispatchQueue.main.async { self.logs = list }
        }
    }

    private func persist(_ list: [LogEntry]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        let tmp = fileURL.deletingLastPathComponent()
            .appendingPathComponent("checkin_logs.json.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
        } catch { }
    }
}
