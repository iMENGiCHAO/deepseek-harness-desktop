// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DeepSeekHarnessDesktop",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "DeepSeekHarnessDesktop",
            path: "Sources/DeepSeekHarnessDesktop"
        )
    ]
)
