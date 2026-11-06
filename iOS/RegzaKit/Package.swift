// swift-tools-version: 6.0
import PackageDescription

// iOS アプリだけで使うモジュール。iOS と Android で共有するもの (RegzaCore) は Packages/RegzaCore にある
let package = Package(
    name: "RegzaKit",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "RegzaAppleStorage", targets: ["RegzaAppleStorage"]),
        .library(name: "RegzaLiveActivity", targets: ["RegzaLiveActivity"]),
        .library(name: "RegzaRemoteUI", targets: ["RegzaRemoteUI"]),
    ],
    dependencies: [
        .package(path: "../../Packages/RegzaCore"),
    ],
    targets: [
        // Apple: キーチェーンへの接続情報保存
        .target(name: "RegzaAppleStorage", dependencies: [.product(name: "RegzaCore", package: "RegzaCore")]),
        // iOS: Live Activity / Dynamic Island と、そのボタン用 App Intents
        .target(
            name: "RegzaLiveActivity",
            dependencies: [.product(name: "RegzaCore", package: "RegzaCore"), "RegzaAppleStorage"]
        ),
        // iOS: SwiftUI のリモコン画面
        .target(
            name: "RegzaRemoteUI",
            dependencies: [.product(name: "RegzaCore", package: "RegzaCore"), "RegzaAppleStorage", "RegzaLiveActivity"]
        ),
    ]
)
