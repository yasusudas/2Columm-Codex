import AppKit
import SwiftTerm
import WebKit

@MainActor
protocol XtermTerminalViewDelegate: AnyObject {
    func xtermTerminalReady(_ source: XtermTerminalView)
    func xtermTerminal(_ source: XtermTerminalView, didSetTitle title: String)
    func xtermTerminal(_ source: XtermTerminalView, processTerminated exitCode: Int32?)
}

final class XtermTerminalView: NSView, @preconcurrency LocalProcessDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    weak var delegate: XtermTerminalViewDelegate?
    private lazy var process = LocalProcess(delegate: self)
    private let userContentController = WKUserContentController()
    private var webView: WKWebView!
    private var pendingOutput: [Data] = []
    private var currentCols = 80
    private var currentRows = 24
    private(set) var isReady = false

    var isProcessRunning: Bool {
        process.running
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        installWebView()
        configureWebView()
        loadTerminalPage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        installWebView()
        configureWebView()
        loadTerminalPage()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        focusTerminal()
        return true
    }

    func focusTerminal() {
        window?.makeFirstResponder(webView)
        evaluateJavaScript("window.codexTerminalFocus?.();")
    }

    func startProcess(
        executable: String,
        args: [String],
        environment: [String],
        currentDirectory: String
    ) {
        terminate()
        evaluateJavaScript("window.codexTerminalReset?.();")
        process.startProcess(
            executable: executable,
            args: args,
            environment: environment,
            currentDirectory: currentDirectory
        )
        focusTerminal()
    }

    func terminate() {
        process.terminate()
    }

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            delegate?.xtermTerminal(self, processTerminated: exitCode)
        }
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        let data = Data(slice)
        guard isReady else {
            pendingOutput.append(data)
            return
        }
        writeToTerminal(data)
    }

    func getWindowSize() -> winsize {
        winsize(
            ws_row: UInt16(max(currentRows, 1)),
            ws_col: UInt16(max(currentCols, 2)),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "terminalBridge",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String
        else {
            return
        }

        switch type {
        case "ready":
            updateSize(from: body)
            isReady = true
            flushPendingOutput()
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                delegate?.xtermTerminalReady(self)
            }
        case "data":
            guard let text = body["data"] as? String else {
                return
            }
            sendToProcess(Array(text.utf8))
        case "binary":
            guard let base64 = body["data"] as? String,
                  let data = Data(base64Encoded: base64)
            else {
                return
            }
            sendToProcess(Array(data))
        case "resize":
            updateSize(from: body)
            synchronizeWindowSize()
        case "title":
            let title = body["title"] as? String ?? ""
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                delegate?.xtermTerminal(self, didSetTitle: title)
            }
        case "openLink":
            if let urlText = body["url"] as? String,
               let url = URL(string: urlText)
            {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }

    private func configureWebView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1.0).cgColor
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setValue(false, forKey: "drawsBackground")
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func installWebView() {
        let configuration = WKWebViewConfiguration()
        userContentController.add(WeakScriptMessageHandler(target: self), name: "terminalBridge")
        configuration.userContentController = userContentController
        webView = WKWebView(frame: .zero, configuration: configuration)
    }

    private func loadTerminalPage() {
        guard let terminalURL = Bundle.main.resourceURL?.appendingPathComponent("WebTerminal"),
              FileManager.default.fileExists(atPath: terminalURL.appendingPathComponent("index.html").path)
        else {
            return
        }

        webView.loadFileURL(
            terminalURL.appendingPathComponent("index.html"),
            allowingReadAccessTo: terminalURL
        )
    }

    private func sendToProcess(_ bytes: [UInt8]) {
        guard process.running else {
            return
        }
        process.send(data: bytes[...])
    }

    private func writeToTerminal(_ data: Data) {
        let base64 = data.base64EncodedString()
        let script = "window.codexTerminalWrite?.(\(Self.javaScriptStringLiteral(base64)));"
        evaluateJavaScript(script)
    }

    private func flushPendingOutput() {
        for data in pendingOutput {
            writeToTerminal(data)
        }
        pendingOutput.removeAll()
    }

    private func updateSize(from body: [String: Any]) {
        currentCols = max(2, Self.intValue(body["cols"]) ?? currentCols)
        currentRows = max(1, Self.intValue(body["rows"]) ?? currentRows)
    }

    private func synchronizeWindowSize() {
        guard process.running else {
            return
        }

        var size = getWindowSize()
        _ = PseudoTerminalHelpers.setWinSize(
            masterPtyDescriptor: process.childfd,
            windowSize: &size
        )
    }

    private func evaluateJavaScript(_ script: String) {
        webView.evaluateJavaScript(script)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private static func javaScriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let arrayLiteral = String(data: data, encoding: .utf8),
              arrayLiteral.count >= 2
        else {
            return "\"\""
        }
        return String(arrayLiteral.dropFirst().dropLast())
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
