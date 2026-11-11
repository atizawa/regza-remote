// swift-tools-version: 6.0
import PackageDescription

// モック生成だけの道具。アプリや Android の依存グラフには含めない。
let package = Package(
    name: "RegzaMockGeneration",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(
            url: "https://github.com/uber/mockolo.git",
            revision: "62fed699ace53bc8ee08a855193a6d1e5e181806")
    ],
    targets: [
        .executableTarget(
            name: "GenerateMocks",
            dependencies: [.product(name: "MockoloFramework", package: "mockolo")],
            path: "Sources")
    ]
)
