// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexPixelTerminal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexPixelTerminal", targets: ["CodexPixelTerminal"]),
    ],
    targets: [
        .executableTarget(
            name: "CodexPixelTerminal"
        ),
    ]
)
