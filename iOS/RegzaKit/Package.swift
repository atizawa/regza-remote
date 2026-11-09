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
        // Apple: キーチェーンへの接続情報保存 (Domain の保存先の protocol を実装するので、組み立て (RegzaApp) に依存する)
        .target(name: "RegzaAppleStorage", dependencies: [.product(name: "RegzaApp", package: "RegzaCore")]),
        // iOS: Live Activity / Dynamic Island と、そのボタン用 App Intents
        // テレビのリモコン (RegzaRemote) を使うので、本物の機器につなぐ組み立て (RegzaApp) に依存する
        .target(
            name: "RegzaLiveActivity",
            dependencies: [.product(name: "RegzaApp", package: "RegzaCore"), "RegzaAppleStorage"]
        ),
        // iOS: SwiftUI の画面。ViewModel の state を読み、send で操作するだけにする。
        // 使えるのは ViewModel と UI の型 (RegzaPresentation) と Live Activity のスイッチだけで、Domain・通信・組み立ては使わない
        // (RegzaPresentation は Domain を外に見せず、MemberImportVisibility で、読み込んでいないモジュールの機能も見えなくする)
        .target(
            name: "RegzaRemoteViews",
            dependencies: [.product(name: "RegzaPresentation", package: "RegzaCore"), "RegzaLiveActivity"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),
        // iOS: アプリの入口 (組み立て)。アプリ全体の ViewModel を RegzaApp (開発用の見本は RegzaSample) で作り、
        // 画面 (RegzaRemoteViews) に渡す。Live Activity とのつなぎと、終了時の後片づけもここで受け持つ
        .target(
            name: "RegzaRemoteUI",
            dependencies: [
                "RegzaRemoteViews",
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "RegzaSample", package: "RegzaCore"),
                "RegzaAppleStorage", "RegzaLiveActivity",
            ]
        ),
        // 画面が下の層 (Domain・通信・組み立て) を import していないことを確かめる (Mac の swift test)
        .testTarget(name: "RegzaKitTests"),
    ]
)
