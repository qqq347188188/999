import SwiftUI
import UIKit

/// 派猫猫旅行卡片：状态机驱动「派发 → 到达 → 领取」，每日幂等。
struct TravelCard: View {
    @StateObject private var store = AccountStore.shared
    @State private var statusText = "—"
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "airplane").foregroundColor(.orange)
                Text("派猫猫旅行").font(.headline)
                Spacer()
                Button { Task { await run() } } label: {
                    if busy { ProgressView() } else { Text("一键旅行 / 领奖") }
                }
                .buttonStyle(.bordered)
            }
            Text(statusText).font(.footnote).foregroundColor(.secondary)

            if !store.accounts.isEmpty {
                ForEach(store.accounts) { acc in
                    HStack {
                        Text(acc.displayName).font(.subheadline)
                        Spacer()
                        Button { Task { await travelOne(acc) } } label: { Text("单个").font(.caption) }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(16)
    }

    private func run() async {
        busy = true
        statusText = "旅行中…"
        var ok = 0, skip = 0, fail = 0
        for acc in store.accounts {
            let r = await CheckinTasks.travelCycle(acc)
            Logger.shared.add(type: "travel", account: acc, ok: r.ok, message: r.message)
            if r.ok { ok += 1 }
            else if r.message.contains("尚未到达") || r.message.contains("已达上限") { skip += 1 }
            else { fail += 1 }
        }
        statusText = "完成：成功 \(ok) · 跳过 \(skip) · 失败 \(fail)"
        busy = false
    }

    private func travelOne(_ acc: Account) async {
        let r = await CheckinTasks.travelCycle(acc)
        Logger.shared.add(type: "travel", account: acc, ok: r.ok, message: r.message)
        statusText = "\(acc.displayName)：\(r.message)"
    }
}
