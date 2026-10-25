import SwiftUI
import UIKit
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var variant: String = "cn"
    @Published var step: Int = 0
    @Published var state: String = ""
    @Published var authUrl: String = ""
    @Published var message: String = "请选择账号区域后开始登录"
    @Published var busy: Bool = false
    @Published var done: Bool = false

    private var timer: Timer?
    private var cancelled = false

    func start() async {
        busy = true
        message = "正在申请登录…"
        cancelled = false
        do {
            let (s, u) = try await APIClient.oauthStart(variant: variant)
            state = s
            authUrl = u
            step = 1
            message = "请在浏览器中完成授权，然后点击下方「检测登录」"
            startPolling()
        } catch {
            message = "申请登录失败：\(error.localizedDescription)"
        }
        busy = false
    }

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { await self.pollOnce() }
        }
    }

    func detectNow() { Task { await pollOnce() } }

    func pollOnce() async {
        guard !cancelled, !state.isEmpty else { return }
        do {
            if let token = try await APIClient.oauthPollToken(variant: variant, state: state) {
                await handleToken(token)
            }
        } catch { }
    }

    private func handleToken(_ token: [String: Any]) async {
        timer?.invalidate()
        guard let accessToken = token["accessToken"] as? String else { return }
        let domain = token["domain"] as? String
        let refreshToken = (token["refreshToken"] as? String) ?? ""
        let tokenType = token["tokenType"] as? String
        let expiresAt = token["expiresAt"] as? Int
        let refreshExpiresAt = token["refreshExpiresAt"] as? Int

        do {
            let profile = try await APIClient.fetchAccountProfile(
                variant: variant, state: state, accessToken: accessToken, domain: domain)
            let pdata = profile["data"] as? [String: Any] ?? profile
            let account = Account(
                id: UUID().uuidString,
                uid: pdata["uid"] as? String,
                nickname: (pdata["nickname"] as? String) ?? (profile["nickname"] as? String),
                email: pdata["email"] as? String,
                enterpriseName: pdata["enterpriseName"] as? String,
                enterpriseId: pdata["enterpriseId"] as? String,
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: tokenType,
                domain: domain ?? (variant == "ai" ? "workbuddy.ai" : nil),
                variant: variant,
                expiresAt: expiresAt,
                refreshExpiresAt: refreshExpiresAt,
                authRaw: nil,
                createdAt: Int(Date().timeIntervalSince1970)
            )
            AccountStore.shared.upsert(account)
            message = "账号已保存"
            done = true
        } catch {
            message = "获取资料失败：\(error.localizedDescription)"
        }
    }

    func cancel() {
        cancelled = true
        timer?.invalidate()
    }
}

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LoginViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if vm.step == 0 {
                    Picker("账号区域", selection: $vm.variant) {
                        Text("国内版 (CodeBuddy/WorkBuddy)").tag("cn")
                        Text("国际版 (WorkBuddy AI)").tag("ai")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button { Task { await vm.start() } } label: {
                        if vm.busy { ProgressView() } else { Text("开始登录") }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    if let url = URL(string: vm.authUrl) {
                        WebView(url: url)
                            .frame(height: 360)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    Button { vm.detectNow() } label: { Text("检测登录") }
                        .buttonStyle(.borderedProminent)
                    Text(vm.message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            }
            .padding(.top)
            .navigationTitle("添加账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { vm.cancel(); dismiss() }
                }
            }
        }
        .onDisappear { vm.cancel() }
        .alert("完成", isPresented: $vm.done) {
            Button("好的") { dismiss() }
        } message: { Text(vm.message) }
    }
}
