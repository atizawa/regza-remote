// swift-tools-version: 6.0
import PackageDescription

// iOS と Android で共有するもの。Domain・Presentation は Foundation を中心に構成する。
// Infrastructure の生成 API クライアントと通信アダプターも、すべてのプラットフォームで共有する。
// Clean Architecture の層ごとにモジュールを分け、依存の向き (Presentation → Domain ← Infrastructure) をコンパイラに守らせる。
// iOS だけのものは iOS/RegzaKit、Android だけのものは Android/RegzaAndroid に置く。
// regza は Mac で ViewModel を動かす CLI (CLI や AI のエージェントが、画面を通さずに状態を読んで操作する)
/// プレゼンテーション層 (共有の ViewModel と、画面の状態・操作の型) のモジュールの設定。
/// Domain は internal で読み込み、画面 (iOS・Android) には UI の型 (SharedModels) だけを見せる
let presentationSettings: [SwiftSetting] = [.enableUpcomingFeature("InternalImportsByDefault")]
/// 機能ごとのプレゼンテーション (Sources/Presentation/<機能>Presentation)。共通 (PresentationCore) だけを使い、ほかの機能を読み込まない
let presentationFeatures = [
    "PlayerPresentation", "GuidePresentation", "ProgramPresentation", "ChannelsPresentation", "ReservationsPresentation",
    "SettingsPresentation",
]
func presentation(_ name: String, _ dependencies: [Target.Dependency]) -> Target {
    .target(
        name: name, dependencies: ["RegzaDomain", "RegzaStrings"] + dependencies, path: "Sources/Presentation/\(name)",
        swiftSettings: presentationSettings)
}

let package = Package(
    name: "RegzaCore",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "RegzaInfrastructure", targets: ["RegzaInfrastructure"]),
        // プレゼンテーション層をまとめて見せる (Android の窓口・組み立て・CLI・テスト)。画面のモジュールは機能ごとのものを使う
        .library(name: "RegzaPresentation", targets: ["RegzaPresentation"]),
        .library(name: "PresentationCore", targets: ["PresentationCore"]),
        .library(name: "AppPresentation", targets: ["AppPresentation"]),
        // UI の型だけ (Android で、これらの型の Java のつなぎを作るのに使う)
        .library(name: "RegzaSharedModels", targets: ["RegzaSharedModels"]),
        // 共有の Swift が画面に出す文言 (OS が起動時に、自分の文言を入れる)
        .library(name: "RegzaStrings", targets: ["RegzaStrings"]),
        // 本物の機器につなぐ組み立て (iOS・Android・CLI)
        .library(name: "RegzaApp", targets: ["RegzaApp"]),
        // つながない見本の組み立て (iOS の開発用の見本・テスト)
        .library(name: "RegzaFakeServers", targets: ["RegzaFakeServers"]),
        .executable(name: "regza", targets: ["RegzaCLI"]),
    ] + presentationFeatures.map { .library(name: $0, targets: [$0]) },
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.14.4"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.13.4"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.8.0"),
    ],
    targets: [
        .plugin(
            name: "GenerateAPI", capability: .buildTool(),
            dependencies: [
                .product(name: "swift-openapi-generator", package: "swift-openapi-generator"),
                .target(name: "PrepareOpenAPI"),
            ]
        ),
        .executableTarget(name: "PrepareOpenAPI", path: "Tools/PrepareOpenAPI"),
        .target(
            name: "RegzaTVAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            exclude: ["openapi-generator-config.yaml"],
            plugins: [.plugin(name: "GenerateAPI")]
        ),
        .target(
            name: "MirakurunAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            exclude: ["openapi-generator-config.yaml"],
            plugins: [.plugin(name: "GenerateAPI")]
        ),
        .target(
            name: "EPGStationAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            exclude: ["openapi-generator-config.yaml"],
            plugins: [.plugin(name: "GenerateAPI")]
        ),
        // Domain: Repository と UseCase の間で使う Data、Repository の protocol、UseCase と SharedModel への変換。SharedModels だけに依存する
        // SharedModels: UI で使う型。Domain の UseCase が Data から作る。Android からも使うので、Java のクラスにできる形にする
        // Strings: 共有の Swift が画面に出す文言。String Catalog から生成したキーで引き、OS が入れた文言を使う (入っていなければ元言語)
        .target(name: "RegzaStrings"),
        .target(name: "RegzaSharedModels", dependencies: ["RegzaStrings"], exclude: ["README.md"]),
        .target(name: "RegzaDomain", dependencies: ["RegzaSharedModels", "RegzaStrings"]),
        // Infrastructure: テレビ・Mirakurun・EPGStation との通信、HTTP、暗号、通信の形から Domain の型への変換 (Mappers)
        .target(
            name: "RegzaInfrastructure",
            dependencies: [
                "RegzaDomain",
                "RegzaStrings",
                "RegzaTVAPI",
                "MirakurunAPI",
                "EPGStationAPI",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]),
        // Presentation: iOS と Android で共有する ViewModel と、画面の状態・操作の型。Domain の UseCase だけを使う (Repository や通信は知らない)。
        // 共通 (処理中の数え方・CLI 向けの約束事・テレビとのつながり・画面の移り変わりの窓口)、機能ごと、アプリ全体に分ける。
        // 機能どうしは読み込まず、アプリ全体が機能をまとめる。Domain を使う初期化などは、同じパッケージの組み立てだけが使える package にする
        presentation("PresentationCore", ["RegzaSharedModels"]),
        presentation("AppPresentation", ["PresentationCore"] + presentationFeatures.map { .target(name: $0) }),
        // プレゼンテーション層をまとめて読み込むためのモジュール (中身は読み込み直しだけ)
        .target(
            name: "RegzaPresentation",
            dependencies: ["PresentationCore", "AppPresentation"] + presentationFeatures.map { .target(name: $0) },
            swiftSettings: presentationSettings
        ),
        // 組み立てる場所 (Composition Root): どの Repository の実装を使うかを決めて AppViewModel を作る
        .target(name: "RegzaApp", dependencies: ["RegzaPresentation", "RegzaInfrastructure"]),
        // 偽物のテレビ・Mirakurun・EPGStation。通信の境界で差し込み、本物の Repository から上をそのまま動かす (プレビュー・振る舞いのテスト・CLI)
        .target(
            name: "RegzaFakeServers",
            dependencies: [
                "RegzaApp",
                "RegzaDomain",
                "RegzaPresentation",
                "RegzaInfrastructure",
                "RegzaTVAPI",
                "MirakurunAPI",
                "EPGStationAPI",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            // iOS のリリースのビルドでは中身をなくす。iOS の画面のモジュールはプレビュー (Debug) のために偽物に依存するので、
            // リリース版のアプリに偽物が入らないようにする (Android・CLI・テストは、リリースのビルドでも偽物を使う)
            swiftSettings: [.define("REGZA_FAKES_DISABLED", .when(platforms: [.iOS], configuration: .release))]),
        .executableTarget(name: "RegzaCLI", dependencies: ["RegzaApp", "RegzaFakeServers"]),
        .testTarget(
            name: "RegzaCoreTests",
            dependencies: [
                "RegzaApp", "RegzaPresentation", "RegzaDomain", "RegzaInfrastructure", "RegzaSharedModels", "RegzaStrings",
                "RegzaFakeServers", "PresentationCore", "AppPresentation",
            ] + presentationFeatures.map { .target(name: $0) }),
    ] + presentationFeatures.map { presentation($0, ["PresentationCore"]) }
)
