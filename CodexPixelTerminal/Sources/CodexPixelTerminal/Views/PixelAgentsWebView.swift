import SwiftUI
import WebKit

struct PixelAgentsWebView: NSViewRepresentable {
    let url: URL?
    let reloadToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView
        load(url, in: webView)
        context.coordinator.lastURL = url
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastURL != url {
            load(url, in: webView)
            context.coordinator.lastURL = url
        } else if context.coordinator.reloadToken != reloadToken {
            context.coordinator.reloadToken = reloadToken
            webView.reload()
        }
    }

    private func load(_ url: URL?, in webView: WKWebView) {
        guard let url else {
            webView.loadHTMLString(
                """
                <html><body style="font: 14px -apple-system; color: #888; display: grid; place-items: center; height: 100vh; margin: 0;">
                Starting Pixel Agents...
                </body></html>
                """,
                baseURL: nil
            )
            return
        }
        webView.load(URLRequest(url: url))
    }

    final class Coordinator {
        weak var webView: WKWebView?
        var lastURL: URL?
        var reloadToken = 0
    }
}
