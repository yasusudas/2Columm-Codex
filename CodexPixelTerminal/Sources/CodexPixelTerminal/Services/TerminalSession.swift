import Combine
import Darwin
import Foundation

@_silgen_name("openpty")
private func cOpenPty(
    _ amaster: UnsafeMutablePointer<Int32>,
    _ aslave: UnsafeMutablePointer<Int32>,
    _ name: UnsafeMutablePointer<CChar>?,
    _ termp: UnsafeMutablePointer<termios>?,
    _ winp: UnsafeMutablePointer<winsize>?
) -> Int32

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
    @Published private(set) var screenText = ""

    private let columns: Int32 = 120
    private let rows: Int32 = 38
    private static weak var current: TerminalSession?
    private var process: Process?
    private var masterHandle: FileHandle?
    private var buffer = TerminalBuffer(columns: 120, rows: 38)

    init() {
        Self.current = self
    }

    func start() {
        guard status != .running, status != .starting else {
            return
        }

        status = .starting
        buffer.reset()
        appendPlain("Starting Codex CLI in \(AppPaths.projectRoot.path)\n")

        var masterFD: Int32 = -1
        var slaveFD: Int32 = -1
        var size = winsize(ws_row: UInt16(rows), ws_col: UInt16(columns), ws_xpixel: 0, ws_ypixel: 0)

        guard cOpenPty(&masterFD, &slaveFD, nil, nil, &size) == 0 else {
            status = .failed
            appendPlain("openpty failed: \(String(cString: strerror(errno)))\n")
            return
        }

        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
        let masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            "-lc",
            """
            cd \(AppPaths.projectRoot.path.shellEscaped) && \
            export TERM=xterm-256color COLORTERM=truecolor CLICOLOR=1 && \
            exec \(AppPaths.codexBinary.shellEscaped)
            """,
        ]
        process.currentDirectoryURL = AppPaths.projectRoot
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { @MainActor [weak self] in
                self?.status = .exited
                self?.appendPlain("\nCodex exited with status \(status).\n")
            }
        }

        masterHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }
            Task { @MainActor [weak self] in
                self?.append(data)
            }
        }

        do {
            try process.run()
            slaveHandle.closeFile()
            self.process = process
            self.masterHandle = masterHandle
            status = .running
        } catch {
            slaveHandle.closeFile()
            masterHandle.closeFile()
            status = .failed
            appendPlain("Failed to start Codex: \(error.localizedDescription)\n")
        }
    }

    func restart() {
        stop()
        start()
    }

    func stop() {
        masterHandle?.readabilityHandler = nil
        process?.terminate()
        masterHandle?.closeFile()
        process = nil
        masterHandle = nil
        if status == .running || status == .starting {
            status = .idle
        }
    }

    static func sharedStop() {
        current?.stop()
    }

    func send(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            return
        }
        try? masterHandle?.write(contentsOf: data)
    }

    private func append(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.buffer.process(text)
            self.screenText = self.buffer.render()
        }
    }

    private func appendPlain(_ text: String) {
        buffer.process(text)
        screenText = buffer.render()
    }
}
