import Foundation

enum AppPaths {
    static let projectRoot = URL(fileURLWithPath: "/Users/yasusu/Desktop/Programing Files/CodexCLI-MOD")
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
    static let nodeBinary = "/usr/local/bin/node"
    static let codexBinary = "/opt/homebrew/bin/codex"
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
        [
            URL(fileURLWithPath: nodeBinary).deletingLastPathComponent().path,
            "/Users/yasusu/.nvm/versions/node/v24.16.0/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ].joined(separator: ":")
    }
}

extension String {
    var shellEscaped: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
