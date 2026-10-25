import SwiftUI

struct LogsView: View {
    @StateObject private var logger = Logger.shared

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f
    }()

    var body: some View {
        NavigationView {
            Group {
                if logger.logs.isEmpty {
                    Text("暂无日志").foregroundColor(.secondary)
                } else {
                    List(logger.logs) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.accountName).font(.subheadline).bold()
                                Spacer()
                                Image(systemName: entry.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(entry.ok ? .green : .red)
                            }
                            Text(entry.message).font(.caption).foregroundColor(.secondary)
                            Text("\(entry.type) · \(Self.formatter.string(from: Date(timeIntervalSince1970: TimeInterval(entry.date))))")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("日志")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") { Logger.shared.clear() }
                }
            }
        }
    }
}
