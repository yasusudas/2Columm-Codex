import AppKit
import SwiftTerm
import SwiftUI

struct TerminalEmulatorView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.nativeBackgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1.0)
        terminalView.nativeForegroundColor = NSColor(calibratedWhite: 0.88, alpha: 1.0)
        terminalView.caretColor = NSColor.systemGreen
        terminalView.selectedTextBackgroundColor = NSColor.systemGreen.withAlphaComponent(0.35)
        terminalView.allowMouseReporting = true
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
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return terminalView
    }

    func updateNSView(_ terminalView: LocalProcessTerminalView, context: Context) {
        if context.coordinator.lastStartRequest != session.startRequest {
            context.coordinator.lastStartRequest = session.startRequest
            context.coordinator.startCodex()
        }
    }

    static func dismantleNSView(_ terminalView: LocalProcessTerminalView, coordinator: Coordinator) {
        terminalView.terminate()
        coordinator.session.unbindTermination()
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        weak var terminalView: LocalProcessTerminalView?
        let session: TerminalSession
        var lastStartRequest = 0

        init(session: TerminalSession) {
            self.session = session
        }

        @MainActor
        func startCodex() {
            guard let terminalView else {
                return
            }

            terminalView.terminate()

            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = AppPaths.appPath
            environment["TERM"] = "xterm-256color"
            environment["COLORTERM"] = "truecolor"
            environment["CLICOLOR"] = "1"

            terminalView.startProcess(
                executable: "/bin/zsh",
                args: [
                    "-lc",
                    "exec \(AppPaths.codexBinary.shellEscaped)",
                ],
                environment: environment.map { "\($0.key)=\($0.value)" },
                currentDirectory: AppPaths.projectRoot.path
            )
            session.markRunning()

            DispatchQueue.main.async {
                terminalView.window?.makeFirstResponder(terminalView)
            }
        }

        @objc
        @MainActor
        func focusTerminal() {
            guard let terminalView else {
                return
            }
            terminalView.window?.makeFirstResponder(terminalView)
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            let session = session
            Task { @MainActor in
                session.setTitle(title)
            }
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func processTerminated(source: TerminalView, exitCode: Int32?) {
            let session = session
            Task { @MainActor in
                session.markExited(exitCode: exitCode)
            }
        }
    }
}
