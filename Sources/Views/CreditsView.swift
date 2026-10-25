import SwiftUI
import UIKit

struct CreditsView: View {
    @StateObject private var store = AccountStore.shared
    @State private var summaries: [String: String] = [:]
    @State private var busy = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    Button { Task { await loadAll() } } label: {
                        if busy { ProgressView() } else { Text("查询额度") }
                    }
                    .buttonStyle(.borderedProminent)

                    if !store.accounts.isEmpty {
                        ForEach(store.accounts) { acc in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(acc.displayName).font(.headline)
                                Text(summaries[acc.id] ?? "未查询")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("额度")
        }
    }

    private func loadAll() async {
        busy = true
        for acc in store.accounts {
            let j = await APIClient.resourceSummary(acc)
            summaries[acc.id] = formatSummary(j)
        }
        busy = false
    }

    private func formatSummary(_ j: [String: Any]?) -> String {
        guard let j = j else { return "查询失败" }
        if let d = j["data"] as? [String: Any] {
            let parts = d.compactMap { (k, v) -> String? in
                if let n = v as? NSNumber { return "\(k): \(n)" }
                if let s = v as? String { return "\(k): \(s)" }
                return nil
            }
            if !parts.isEmpty { return parts.joined(separator: "\n") }
            return String(describing: d)
        }
        return String(describing: j)
    }
}
