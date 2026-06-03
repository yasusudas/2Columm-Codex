import Foundation

enum AppPaths {
    private static let bundledProjectRoot = URL(fileURLWithPath: "/Users/yasusu/Desktop/Programing Files/CodexCLI-MOD")

    static var projectRoot: URL {
        if FileManager.default.fileExists(atPath: bundledProjectRoot.path) {
            return bundledProjectRoot
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var pixelAgentsRoot: URL {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("PixelAgents"),
           FileManager.default.fileExists(atPath: bundled.appendingPathComponent("dist/cli.js").path)
        {
            return bundled
        }
        return projectRoot.appendingPathComponent("pixel-agents-main")
    }
    static var pixelAgentsCli: URL {
        pixelAgentsRoot.appendingPathComponent("dist/cli.js")
    }
    static var nodeBinary: String {
        resolvedNodeBinary ?? "/usr/bin/node"
    }

    static var codexBinary: String {
        resolvedCodexBinary ?? "/opt/homebrew/bin/codex"
    }

    static var resolvedNodeBinary: String? {
        resolveExecutable(
            named: "node",
            candidates: [
                "/opt/homebrew/bin/node",
                "/usr/local/bin/node",
            ] + nvmNodeCandidates
        )
    }

    static var resolvedCodexBinary: String? {
        resolveExecutable(
            named: "codex",
            candidates: [
                "/opt/homebrew/bin/codex",
                "/usr/local/bin/codex",
                "/Users/yasusu/.nvm/versions/node/v24.16.0/bin/codex",
            ]
        )
    }

    static let pixelAgentsHost = "127.0.0.1"
    static let pixelAgentsPort = 3100
    static let realCodexHome = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".codex")
    static let pixelAgentsHome = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexPixelTerminal/Home")
    static let pixelAgentsDiscovery = pixelAgentsHome
        .appendingPathComponent(".pixel-agents-for-codex/server.json")

    static var pixelAgentsURL: URL {
        URL(string: "http://\(pixelAgentsHost):\(pixelAgentsPort)")!
    }

    static var appPath: String {
        let resolvedDirectories = [
            resolvedCodexBinary,
            resolvedNodeBinary,
        ]
        .compactMap { $0 }
        .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }

        let fallbackDirectories = [
            URL(fileURLWithPath: nodeBinary).deletingLastPathComponent().path,
            "/Users/yasusu/.nvm/versions/node/v24.16.0/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]

        let inheritedDirectories = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []

        return uniquePathItems(resolvedDirectories + fallbackDirectories + inheritedDirectories)
            .joined(separator: ":")
    }

    private static var nvmNodeCandidates: [String] {
        let nvmVersions = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".nvm/versions/node")

        guard let versions = try? FileManager.default.contentsOfDirectory(
            at: nvmVersions,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return versions
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .map { $0.appendingPathComponent("bin/node").path }
    }

    private static func resolveExecutable(named name: String, candidates: [String]) -> String? {
        let pathCandidates = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent(name).path } ?? []

        for candidate in uniquePathItems(candidates + pathCandidates) {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func uniquePathItems(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items where !item.isEmpty && seen.insert(item).inserted {
            result.append(item)
        }
        return result
    }
}

extension String {
    var shellEscaped: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
