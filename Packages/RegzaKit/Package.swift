// swift-tools-version: 6.0
import PackageDescription

// RegzaCore は Foundation のみに依存し、Android (Swift SDK for Android) でもビルドできるようにする。
// それ以外のモジュールは iOS 専用で、ソースは `#if os(iOS)` で囲んでいる。
let package = Package(
    name: "RegzaKit",
    defaultLocalization: "ja",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RegzaCore", targets: ["RegzaCore"]),
        .library(name: "RegzaAppleStorage", targets: ["RegzaAppleStorage"]),
        .library(name: "RegzaLiveActivity", targets: ["RegzaLiveActivity"]),
        .library(name: "RegzaRemoteUI", targets: ["RegzaRemoteUI"]),
    ],
    targets: [
        // クロスプラットフォーム: キーコード、HTTP/Digest 認証クライアント、status 解析
        .target(name: "RegzaCore"),
        // Apple: キーチェーンへの接続情報保存
        .target(name: "RegzaAppleStorage", dependencies: ["RegzaCore"]),
        // iOS: Live Activity / Dynamic Island と、そのボタン用 App Intents
        .target(name: "RegzaLiveActivity", dependencies: ["RegzaCore", "RegzaAppleStorage"]),
        // iOS: SwiftUI のリモコン画面
        .target(name: "RegzaRemoteUI", dependencies: ["RegzaCore", "RegzaAppleStorage", "RegzaLiveActivity"]),
        .testTarget(name: "RegzaCoreTests", dependencies: ["RegzaCore"]),
    ]
)
