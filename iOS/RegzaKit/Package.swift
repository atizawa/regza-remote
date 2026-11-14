// swift-tools-version: 6.0
import PackageDescription

// iOS 固有の組み立て・画面・システム連携。共有の Domain・UseCase・ViewModel は RegzaCore に置く。
let package = Package(
    name: "RegzaKit",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "AppServices", targets: ["AppServices"]),
        .library(name: "UI", targets: ["UI"]),
        .library(name: "LiveActivity", targets: ["LiveActivity"]),
        .library(name: "SystemActions", targets: ["SystemActions"]),
        .library(name: "Shortcuts", targets: ["Shortcuts"]),
        .library(name: "Widgets", targets: ["Widgets"]),
    ],
    dependencies: [.package(path: "../../Packages/RegzaCore")],
    targets: [
        // アプリ・Widget で共有する色やサイズ。
        .target(name: "Design", resources: [.process("Generated/DesignColors.xcassets")]),
        // 文言の定義元。AndroidのXMLもこのString Catalogから生成する。
        .target(name: "Localization", resources: [.process("Resources")]),
        // Live Activity の状態と更新。画面と同じく共有 ViewModel だけを使う。
        .target(
            name: "LiveActivity",
            dependencies: [.product(name: "RegzaPresentation", package: "RegzaCore")],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]),
        // iOS の保存実装を共通 Factory に渡し、アプリ全体の依存を保持する。
        // 画面・Siri・Live Activity の操作は同じ AppContainer を使う。
        .target(
            name: "AppServices",
            dependencies: [
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "RegzaInfrastructure", package: "RegzaCore"),
                .product(name: "RegzaSample", package: "RegzaCore"),
                "LiveActivity",
            ]),
        // アプリと Widget の両方に登録する、ボタンからの操作。
        .target(
            name: "SystemActions",
            dependencies: ["AppServices", .product(name: "RegzaPresentation", package: "RegzaCore")]),
        // アプリだけに登録する Siri・ショートカット。Widget 拡張への依存には含めない。
        .target(
            name: "Shortcuts",
            dependencies: ["AppServices", "LiveActivity", .product(name: "RegzaApp", package: "RegzaCore")]),
        // ホーム画面・Live Activity・コントロールセンターの表示。
        .target(
            name: "Widgets",
            dependencies: [
                .product(name: "RegzaPresentation", package: "RegzaCore"),
                "LiveActivity", "SystemActions", "Design",
            ]),
        // 画面は ViewModel の state と Action を使い、DI・Domain・通信を扱わない。
        // RootView は Xcode のアプリターゲットに置き、このモジュールへ依存を渡す。
        .target(
            name: "UI",
            dependencies: [.product(name: "RegzaPresentation", package: "RegzaCore"), "Design", "LiveActivity", "Localization"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]),
        .testTarget(
            name: "RegzaKitTests",
            dependencies: ["AppServices", .product(name: "RegzaInfrastructure", package: "RegzaCore")]),
    ]
)
