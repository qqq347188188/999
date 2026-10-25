import SwiftUI
import UIKit

struct AccountsView: View {
    @StateObject private var store = AccountStore.shared
    @State private var showLogin = false
    @State private var showImport = false
    @State private var importText = ""
    @State private var importResult: String?
    @State private var exported = false

    var body: some View {
        NavigationView {
            Group {
                if store.accounts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.largeTitle).foregroundColor(.orange)
                        Text("还没有账号").font(.headline)
                        Text("点击右上角「•••」添加 WorkBuddy / CodeBuddy 账号")
                            .font(.footnote).foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(store.accounts) { acc in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(acc.displayName).font(.headline)
                                    Spacer()
                                    Text(acc.variantLabel)
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(6)
                                }
                                Text(acc.domain ?? acc.variant)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .onDelete { indices in
                            indices.forEach { store.delete(store.accounts[$0].id) }
                        }
                    }
                }
            }
            .navigationTitle("账号")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showLogin = true } label: { Label("添加账号", systemImage: "plus") }
                        Button { showImport = true } label: { Label("导入", systemImage: "square.and.arrow.down") }
                        Button { exportAccounts() } label: { Label("导出", systemImage: "square.and.arrow.up") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showLogin) { LoginView() }
            .sheet(isPresented: $showImport) { importSheet }
            .alert("已导出", isPresented: $exported) {
                Button("好的", role: .cancel) { }
            } message: { Text("账号 JSON 已复制到剪贴板") }
        }
    }

    private var importSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                Text("粘贴 Android / 桌面版导出的 accounts.json 内容：")
                    .font(.footnote)
                TextEditor(text: $importText)
                    .border(Color.secondary)
                    .frame(minHeight: 200)
                if let r = importResult {
                    Text(r).foregroundColor(.green).font(.footnote)
                }
                Button("导入") {
                    let res = store.importJSON(importText)
                    importResult = "新增 \(res.imported) · 覆盖 \(res.overwritten) · 跳过 \(res.skipped)"
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
            .navigationTitle("导入账号")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showImport = false }
                }
            }
        }
    }

    private func exportAccounts() {
        UIPasteboard.general.string = store.exportJSON()
        exported = true
    }
}
