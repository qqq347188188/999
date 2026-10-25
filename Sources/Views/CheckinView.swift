import SwiftUI
import UIKit

struct CheckinView: View {
    @StateObject private var store = AccountStore.shared
    @State private var results: [String: CheckinResult.Status] = [:]
    @State private var busy = false
    @State private var lastMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("WB 每日签到").font(.title2).bold()
                        Text(lastMessage.isEmpty ? "点击下方按钮为所有账号签到" : lastMessage)
                            .font(.footnote).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button { Task { await checkinAll() } } label: {
                            if busy { ProgressView() } else { Text("一键签到") }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(16)

                    if !store.accounts.isEmpty {
                        ForEach(store.accounts) { acc in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(acc.displayName).font(.headline)
                                    Text(acc.variantLabel).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                statusBadge(acc.id)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }

                    TravelCard()
                }
                .padding()
            }
            .navigationTitle("签到")
        }
    }

    @ViewBuilder
    private func statusBadge(_ id: String) -> some View {
        switch results[id] {
        case .success:
            Label("成功", systemImage: "checkmark.circle.fill").foregroundColor(.green)
        case .already:
            Label("已签", systemImage: "checkmark.circle").foregroundColor(.gray)
        case .error:
            Label("失败", systemImage: "xmark.circle.fill").foregroundColor(.red)
        default:
            Label("未签", systemImage: "circle").foregroundColor(.secondary)
        }
    }

    private func checkinAll() async {
        busy = true
        lastMessage = "签到中…"
        var ok = 0, already = 0, fail = 0
        for acc in store.accounts {
            let r = await APIClient.dailyCheckin(acc)
            results[acc.id] = r.status
            Logger.shared.add(type: "checkin", account: acc,
                              ok: r.status == .success || r.status == .already,
                              message: r.message)
            switch r.status {
            case .success: ok += 1
            case .already: already += 1
            default: fail += 1
            }
        }
        lastMessage = "完成：成功 \(ok) · 已签 \(already) · 失败 \(fail)"
        busy = false
    }
}
