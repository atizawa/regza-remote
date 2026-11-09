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
        .target(name: "RegzaAppleStorage", dependencies: [.product(name: "RegzaPresentation", package: "RegzaCore")]),
        // iOS: Live Activity / Dynamic Island と、そのボタン用 App Intents
        // テレビのリモコン (RegzaRemote) を使うので、本物の機器につなぐ組み立て (RegzaApp) に依存する
        .target(
            name: "RegzaLiveActivity",
            dependencies: [.product(name: "RegzaApp", package: "RegzaCore"), "RegzaAppleStorage"]
        ),
        // iOS: SwiftUI のリモコン画面。アプリ全体の ViewModel は RegzaApp (開発用の見本は RegzaSample) で組み立てる
        .target(
            name: "RegzaRemoteUI",
            dependencies: [
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "RegzaSample", package: "RegzaCore"),
                "RegzaAppleStorage", "RegzaLiveActivity",
            ]
        ),
    ]
)
