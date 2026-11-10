// swift-tools-version: 6.0
import PackageDescription

// iOS アプリだけで使うモジュール。iOS と Android で共有するもの (RegzaCore) は Packages/RegzaCore にある。
// iOS だけの機能 (Live Activity・ウィジェット・Siri) も、画面と同じく共有の ViewModel の state を読み、Action を送る
let package = Package(
    name: "RegzaKit",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "RegzaAppleStorage", targets: ["RegzaAppleStorage"]),
        .library(name: "RegzaLiveActivity", targets: ["RegzaLiveActivity"]),
        .library(name: "RegzaRemoteIntents", targets: ["RegzaRemoteIntents"]),
        .library(name: "RegzaSiriIntents", targets: ["RegzaSiriIntents"]),
        .library(name: "RegzaWidgets", targets: ["RegzaWidgets"]),
        .library(name: "RegzaAppContainer", targets: ["RegzaAppContainer"]),
        .library(name: "RegzaRemoteUI", targets: ["RegzaRemoteUI"]),
    ],
    dependencies: [
        .package(path: "../../Packages/RegzaCore")
    ],
    targets: [
        // Apple: キーチェーンへの接続情報保存 (Domain の保存先の protocol を実装するので、組み立て (RegzaApp) に依存する)
        .target(name: "RegzaAppleStorage", dependencies: [.product(name: "RegzaApp", package: "RegzaCore")]),
        // iOS: アプリとウィジェットで共通の色
        .target(name: "RegzaDesign"),
        // iOS: Live Activity (ロック画面と Dynamic Island) の表示と、閉じている間の更新の予約。
        // 画面と同じく、RemoteViewModel の state を読むだけにする (Domain・通信・組み立ては使わない)
        .target(
            name: "RegzaLiveActivity",
            dependencies: [.product(name: "RegzaPresentation", package: "RegzaCore")],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),
        // iOS: アプリのプロセスに 1 つだけ置く、アプリ全体の ViewModel の組み立て。
        // 画面と、画面のない入口 (Live Activity のボタン・Siri・閉じている間の更新) が同じものを使う
        .target(
            name: "RegzaAppContainer",
            dependencies: [
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "RegzaSample", package: "RegzaCore"),
                "RegzaAppleStorage", "RegzaLiveActivity",
            ]
        ),
        // iOS: Live Activity・ウィジェット・コントロールセンターのボタンから、キーを送る App Intent (アプリのプロセスで動く)。
        // アプリとウィジェットの両方に登録する
        .target(
            name: "RegzaRemoteIntents",
            dependencies: ["RegzaAppContainer", "RegzaLiveActivity", .product(name: "RegzaApp", package: "RegzaCore")]),
        // iOS: Siri・ショートカットの App Intent。アプリのプロセスの ViewModel を使うので、アプリにだけ登録する
        // (ウィジェットにも登録すると、拡張機能のプロセスで動くことがある)
        .target(
            name: "RegzaSiriIntents",
            dependencies: ["RegzaAppContainer", "RegzaLiveActivity", .product(name: "RegzaApp", package: "RegzaCore")]),
        // iOS: Live Activity・ホーム画面のウィジェット・コントロールセンターの見た目 (ウィジェットの拡張機能が使う)
        .target(
            name: "RegzaWidgets",
            dependencies: [
                .product(name: "RegzaPresentation", package: "RegzaCore"), "RegzaLiveActivity", "RegzaRemoteIntents", "RegzaDesign",
            ]),
        // iOS: SwiftUI の画面。ViewModel の state を読み、send で操作するだけにする。
        // 使えるのは ViewModel と UI の型 (RegzaPresentation)、色、Live Activity のスイッチだけで、Domain・通信・組み立ては使わない
        // (RegzaPresentation は Domain を外に見せず、MemberImportVisibility で、読み込んでいないモジュールの機能も見えなくする)
        .target(
            name: "RegzaRemoteViews",
            dependencies: [.product(name: "RegzaPresentation", package: "RegzaCore"), "RegzaDesign", "RegzaLiveActivity"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]
        ),
        // iOS: アプリの入口。アプリのプロセスの ViewModel (RegzaAppContainer) を画面 (RegzaRemoteViews) に渡す。
        // 終了時の後片づけもここで受け持つ
        .target(
            name: "RegzaRemoteUI",
            dependencies: ["RegzaRemoteViews", "RegzaAppContainer", .product(name: "RegzaApp", package: "RegzaCore")]
        ),
        // 画面と Live Activity が下の層 (Domain・通信・組み立て) を import していないことを確かめる (Mac の swift test)
        .testTarget(name: "RegzaKitTests"),
    ]
)
