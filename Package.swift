// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeQuotaMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeQuotaMenuBar",
            path: "Sources/ClaudeQuotaMenuBar"
        )
    ]
)
