// swift-tools-version: 6.0
import PackageDescription

// iOS 固有の組み立て・画面・システム連携。共有の Domain・UseCase・ViewModel は RegzaCore に置く。

/// 画面のモジュールの設定 (ほかのモジュールの型の操作は、そのモジュールを読み込んだファイルでだけ使える)
let screenSettings: [SwiftSetting] = [.enableUpcomingFeature("MemberImportVisibility")]
/// 画面のファイルの末尾のプレビュー (`#if DEBUG`) だけが使う、偽物のテレビ・録画サーバー。
/// iOS のリリースのビルドでは中身のないモジュールになるので (RegzaCore の Package.swift)、リリース版のアプリには入らない
let fakeForPreviews: Target.Dependency = .product(name: "RegzaFakeServers", package: "RegzaCore")
/// 機能の画面のモジュール (Sources/UI/<機能>UI)。画面の ViewModel の state と Action・共通の部品だけを使い、ほかの機能を読み込まない
func feature(_ name: String) -> Target {
    .target(
        name: name,
        dependencies: [
            .product(name: "RegzaPresentation", package: "RegzaCore"), "Design", "Localization", "UICommon", fakeForPreviews,
        ],
        path: "Sources/UI/\(name)",
        swiftSettings: screenSettings)
}
let features = [
    "RemoteUI", "PlayerUI", "GuideUI", "ProgramUI", "ChannelsUI", "ReservationsUI", "SettingsUI",
]

let package = Package(
    name: "RegzaKit",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "AppServices", targets: ["AppServices"]),
        .library(name: "AppUI", targets: ["AppUI"]),
        .library(name: "LiveActivity", targets: ["LiveActivity"]),
        .library(name: "SystemActions", targets: ["SystemActions"]),
        .library(name: "Shortcuts", targets: ["Shortcuts"]),
        .library(name: "Widgets", targets: ["Widgets"]),
        // 機能ごとのスキーム (Xcode が作る) でプレビューすると、その機能と依存だけをビルドする。アプリは UI だけを読み込む
    ] + features.map { .library(name: $0, targets: [$0]) },
    dependencies: [.package(path: "../../Packages/RegzaCore")],
    targets: [
        // アプリ・Widget で共有する色やサイズ。
        .target(name: "Design", resources: [.process("Generated/DesignColors.xcassets")]),
        // 文言の定義元。AndroidのXMLもこのString Catalogから生成する。
        .target(
            name: "Localization", dependencies: [.product(name: "RegzaStrings", package: "RegzaCore")],
            resources: [.process("Resources")]),
        // Live Activity の状態と更新。画面と同じく共有 ViewModel だけを使う。
        .target(
            name: "LiveActivity",
            dependencies: [.product(name: "RegzaPresentation", package: "RegzaCore"), "Localization"],
            swiftSettings: [.enableUpcomingFeature("MemberImportVisibility")]),
        // iOS の保存実装を共通 Factory に渡し、アプリ全体の依存を保持する。
        // 画面・Siri・Live Activity の操作は同じ AppContainer を使う。
        .target(
            name: "AppServices",
            dependencies: [
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "RegzaInfrastructure", package: "RegzaCore"),
                "LiveActivity", "Localization",
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
                "LiveActivity", "SystemActions", "Design", "Localization",
            ]),
        // 画面は ViewModel の state と Action を使い、DI・Domain・通信を扱わない。
        // 機能ごとのモジュールが共通に使う部品・画面の移り先の受け取り口・プレビューの準備
        .target(
            name: "UICommon",
            dependencies: [
                .product(name: "RegzaPresentation", package: "RegzaCore"), "Design", "LiveActivity", "Localization", fakeForPreviews,
            ],
            path: "Sources/UI/UICommon",
            swiftSettings: screenSettings),
        // 画面の組み立て (タブ・タブの中で開く画面)。機能の画面のモジュール (<機能>UI) をつなぐ。
        // RootView は Xcode のアプリターゲットに置き、このモジュールへ依存を渡す。アプリはこのモジュールだけを読み込む
        .target(
            name: "AppUI",
            dependencies: [
                .product(name: "RegzaPresentation", package: "RegzaCore"), "Design", "LiveActivity", "Localization", "UICommon",
                fakeForPreviews,
            ] + features.map { .target(name: $0) },
            path: "Sources/UI/AppUI",
            swiftSettings: screenSettings),
    ] + features.map(feature) + [
        .testTarget(
            name: "RegzaKitTests",
            dependencies: ["AppServices", "Localization", .product(name: "RegzaInfrastructure", package: "RegzaCore")])
    ]
)
