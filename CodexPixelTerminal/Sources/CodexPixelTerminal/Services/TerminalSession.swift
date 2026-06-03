import Foundation

@MainActor
final class TerminalSession: ObservableObject {
    enum Status {
        case idle
        case starting
        case running
        case exited
        case failed
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var startRequest = 0
    @Published private(set) var terminalTitle = "Codex CLI"

    private static weak var current: TerminalSession?
    private var terminateProcess: (@MainActor () -> Void)?

    init() {
        Self.current = self
    }

    func start() {
        guard status != .running, status != .starting else {
            return
        }
        status = .starting
        startRequest += 1
    }

    func restart() {
        status = .starting
        startRequest += 1
    }

    func stop() {
        terminateProcess?()
        if status == .running || status == .starting {
            status = .idle
        }
    }

    static func sharedStop() {
        current?.stop()
    }

    func bindTermination(_ handler: @escaping @MainActor () -> Void) {
        terminateProcess = handler
    }

    func unbindTermination() {
        terminateProcess = nil
    }

    func markRunning() {
        status = .running
    }

    func markExited(exitCode: Int32?) {
        status = .exited
        if let exitCode {
            terminalTitle = "Codex exited: \(exitCode)"
        } else {
            terminalTitle = "Codex exited"
        }
    }

    func markFailed(_ message: String) {
        status = .failed
        terminalTitle = message
    }

    func setTitle(_ title: String) {
        terminalTitle = title.isEmpty ? "Codex CLI" : title
    }
}
