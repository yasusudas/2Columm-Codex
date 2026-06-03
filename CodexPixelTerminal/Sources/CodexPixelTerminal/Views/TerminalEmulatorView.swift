import AppKit
import SwiftUI

struct TerminalEmulatorView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> XtermTerminalView {
        let terminalView = XtermTerminalView(frame: .zero)
        terminalView.delegate = context.coordinator
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.terminalView = terminalView
        let clickRecognizer = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.focusTerminal)
        )
        clickRecognizer.delaysPrimaryMouseButtonEvents = false
        terminalView.addGestureRecognizer(clickRecognizer)
        session.bindTermination { [weak terminalView] in
            terminalView?.terminate()
        }

        DispatchQueue.main.async {
            terminalView.focusTerminal()
        }

        return terminalView
    }

    func updateNSView(_ terminalView: XtermTerminalView, context: Context) {
        if context.coordinator.lastStartRequest != session.startRequest {
            context.coordinator.lastStartRequest = session.startRequest
            context.coordinator.startCodex()
        }
    }

    static func dismantleNSView(_ terminalView: XtermTerminalView, coordinator: Coordinator) {
        terminalView.terminate()
        coordinator.session.unbindTermination()
    }

    final class Coordinator: NSObject, XtermTerminalViewDelegate {
        weak var terminalView: XtermTerminalView?
        let session: TerminalSession
        var lastStartRequest = 0
        private var pendingStart = false

        init(session: TerminalSession) {
            self.session = session
        }

        @MainActor
        func startCodex() {
            guard let terminalView else {
                return
            }

            guard terminalView.isReady else {
                pendingStart = true
                return
            }

            guard let codexBinary = AppPaths.resolvedCodexBinary else {
                session.markFailed("Codex CLI executable was not found in PATH or common install locations.")
                return
            }

            if terminalView.isProcessRunning {
                session.ignoreNextTerminationCallback()
            }

            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = AppPaths.appPath
            environment["TERM"] = "xterm-256color"
            environment["COLORTERM"] = "truecolor"
            environment["CLICOLOR"] = "1"

            terminalView.startProcess(
                executable: "/bin/zsh",
                args: [
                    "-lc",
                    "exec \(codexBinary.shellEscaped)",
                ],
                environment: environment.map { "\($0.key)=\($0.value)" },
                currentDirectory: AppPaths.projectRoot.path
            )
            session.markRunning()
            pendingStart = false
        }

        @objc
        @MainActor
        func focusTerminal() {
            guard let terminalView else {
                return
            }
            terminalView.focusTerminal()
        }

        func xtermTerminalReady(_ source: XtermTerminalView) {
            if pendingStart || lastStartRequest > 0 {
                startCodex()
            }
        }

        func xtermTerminal(_ source: XtermTerminalView, didSetTitle title: String) {
            let session = session
            Task { @MainActor in
                session.setTitle(title)
            }
        }

        func xtermTerminal(_ source: XtermTerminalView, processTerminated exitCode: Int32?) {
            let session = session
            Task { @MainActor in
                session.handleProcessTerminated(exitCode: exitCode)
            }
        }
    }
}
