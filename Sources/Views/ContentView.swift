import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AccountsView()
                .tabItem { Label("账号", systemImage: "person.2.fill") }
            CheckinView()
                .tabItem { Label("签到", systemImage: "checkmark.circle.fill") }
            CreditsView()
                .tabItem { Label("额度", systemImage: "banknote.fill") }
            LogsView()
                .tabItem { Label("日志", systemImage: "doc.plaintext.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .accentColor(.orange)
    }
}
