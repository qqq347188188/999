import SwiftUI
import WebKit

/// 用于在登录流程中展示授权页面的 WKWebView 封装。
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.allowsBackForwardNavigationGestures = false
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
