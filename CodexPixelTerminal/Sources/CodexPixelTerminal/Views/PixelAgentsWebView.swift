import SwiftUI
import WebKit

struct PixelAgentsWebView: NSViewRepresentable {
    let url: URL?
    let reloadToken: Int
    let onLaunchAgent: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLaunchAgent: onLaunchAgent)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "pixelAgentsBridge")
        configuration.userContentController = userContentController
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

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var lastURL: URL?
        var reloadToken = 0
        private let onLaunchAgent: () -> Void

        init(onLaunchAgent: @escaping () -> Void) {
            self.onLaunchAgent = onLaunchAgent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "pixelAgentsBridge",
                  let body = message.body as? [String: Any],
                  body["type"] as? String == "launchAgent"
            else {
                return
            }
            onLaunchAgent()
        }
    }
}
