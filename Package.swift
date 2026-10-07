// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BedrockMeter",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "BedrockMeterCore",
            path: "Sources/BedrockMeterCore"
        ),
        .executableTarget(
            name: "BedrockMeter",
            dependencies: ["BedrockMeterCore"],
            path: "Sources/BedrockMeter"
        ),
        .testTarget(
            name: "BedrockMeterCoreTests",
            dependencies: ["BedrockMeterCore"],
            path: "Tests/BedrockMeterCoreTests"
        ),
    ]
)
