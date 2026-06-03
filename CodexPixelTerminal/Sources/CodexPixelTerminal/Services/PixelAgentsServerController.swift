import Combine
import Foundation

@MainActor
final class PixelAgentsServerController: ObservableObject {
    enum Status {
        case idle
        case starting
        case running
        case failed
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var webURL: URL?
    @Published private(set) var message = ""
    @Published private(set) var reloadToken = 0

    private static weak var current: PixelAgentsServerController?
    private var process: Process?
    private var pipe: Pipe?
    private var startTask: Task<Void, Never>?
    private let discoveryURL = AppPaths.pixelAgentsDiscovery

    init() {
        Self.current = self
    }

    func start() {
        guard status != .running, status != .starting else {
            return
        }

        status = .starting
        message = "Starting local Pixel Agents server..."

        startTask?.cancel()
        startTask = Task { [weak self] in
            await self?.startServer()
        }
    }

    func reload() {
        reloadToken += 1
    }

    func stop() {
        startTask?.cancel()
        process?.terminate()
        process = nil
        pipe = nil
        status = .idle
        webURL = nil
    }

    static func sharedStop() {
        current?.stop()
    }

    @MainActor
    private func markRunning(url: URL = AppPaths.pixelAgentsURL) {
        status = .running
        webURL = url
        message = ""
    }

    @MainActor
    private func markFailed(_ text: String) {
        status = .failed
        message = text
    }

    private func startServer() async {
        preparePixelAgentsHome()

        if await isHealthy() {
            markRunning()
            return
        }
        if let discoveredURL = await healthyDiscoveryURL() {
            markRunning(url: discoveredURL)
            return
        }
        await removeStaleDiscoveryIfNeeded()

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: AppPaths.nodeBinary)
        process.arguments = [
            AppPaths.pixelAgentsCli.path,
            "--host",
            AppPaths.pixelAgentsHost,
            "--port",
            String(AppPaths.pixelAgentsPort),
        ]
        process.currentDirectoryURL = AppPaths.projectRoot
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = AppPaths.pixelAgentsHome.path
        environment["PATH"] = AppPaths.appPath
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else {
                return
            }
            Task { @MainActor [weak self] in
                self?.message = output
                    .split(separator: "\n")
                    .suffix(2)
                    .joined(separator: "\n")
            }
        }

        do {
            try process.run()
            self.process = process
            self.pipe = pipe
        } catch {
            markFailed("Failed to start Pixel Agents: \(error.localizedDescription)")
            return
        }

        for _ in 0..<80 {
            if Task.isCancelled {
                return
            }
            if await isHealthy() {
                markRunning()
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        markFailed("Pixel Agents did not become ready at \(AppPaths.pixelAgentsURL.absoluteString)")
    }

    private func isHealthy() async -> Bool {
        await isHealthy(port: AppPaths.pixelAgentsPort)
    }

    private func isHealthy(port: Int) async -> Bool {
        guard let url = URL(string: "http://\(AppPaths.pixelAgentsHost):\(port)/api/health") else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func healthyDiscoveryURL() async -> URL? {
        guard let discovery = readDiscovery() else {
            return nil
        }
        guard await isHealthy(port: discovery.port) else {
            return nil
        }
        return URL(string: "http://\(AppPaths.pixelAgentsHost):\(discovery.port)")
    }

    private func removeStaleDiscoveryIfNeeded() async {
        guard let discovery = readDiscovery() else {
            return
        }
        if await !isHealthy(port: discovery.port) {
            try? FileManager.default.removeItem(at: discoveryURL)
        }
    }

    private func readDiscovery() -> PixelAgentsDiscovery? {
        guard let data = try? Data(contentsOf: discoveryURL) else {
            return nil
        }
        return try? JSONDecoder().decode(PixelAgentsDiscovery.self, from: data)
    }

    private func preparePixelAgentsHome() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(
            at: AppPaths.pixelAgentsHome,
            withIntermediateDirectories: true
        )

        let codexLink = AppPaths.pixelAgentsHome.appendingPathComponent(".codex")
        if !fileManager.fileExists(atPath: codexLink.path) {
            try? fileManager.createSymbolicLink(
                at: codexLink,
                withDestinationURL: AppPaths.realCodexHome
            )
        }
    }
}

private struct PixelAgentsDiscovery: Decodable {
    let port: Int
}
