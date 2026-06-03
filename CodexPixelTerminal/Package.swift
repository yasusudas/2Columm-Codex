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
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", .upToNextMajor(from: "1.13.0")),
    ],
    targets: [
        .executableTarget(
            name: "CodexPixelTerminal",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
    ]
)
