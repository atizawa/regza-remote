// swift-tools-version: 6.0
import PackageDescription

// iOS と Android で共有するもの。Domain・Presentation は Foundation を中心に構成する。
// Infrastructure の生成 API クライアントと通信アダプターも、すべてのプラットフォームで共有する。
// Clean Architecture の層ごとにモジュールを分け、依存の向き (Presentation → Domain ← Infrastructure) をコンパイラに守らせる。
// iOS だけのものは iOS/RegzaKit、Android だけのものは Android/RegzaAndroid に置く。
// regza は Mac で ViewModel を動かす CLI (CLI や AI のエージェントが、画面を通さずに状態を読んで操作する)
let package = Package(
    name: "RegzaCore",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "RegzaInfrastructure", targets: ["RegzaInfrastructure"]),
        .library(name: "RegzaPresentation", targets: ["RegzaPresentation"]),
        // UI の型だけ (Android で、これらの型の Java のつなぎを作るのに使う)
        .library(name: "RegzaSharedModels", targets: ["RegzaSharedModels"]),
        // 本物の機器につなぐ組み立て (iOS・Android・CLI)
        .library(name: "RegzaApp", targets: ["RegzaApp"]),
        // つながない見本の組み立て (iOS の開発用の見本・テスト)
        .library(name: "RegzaSample", targets: ["RegzaSample"]),
        .executable(name: "regza", targets: ["RegzaCLI"]),
    ],
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
        .target(name: "RegzaSharedModels", exclude: ["README.md"]),
        .target(name: "RegzaDomain", dependencies: ["RegzaSharedModels"]),
        // Infrastructure: テレビ・Mirakurun・EPGStation との通信、HTTP、暗号、通信の形から Domain の型への変換 (Mappers)
        .target(
            name: "RegzaInfrastructure",
            dependencies: [
                "RegzaDomain",
                "RegzaTVAPI",
                "MirakurunAPI",
                "EPGStationAPI",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]),
        // Presentation: iOS と Android で共有する ViewModel。Domain の UseCase だけを使う (Repository や通信は知らない)
        // 画面 (iOS・Android) には UI の型 (SharedModels) だけを見せる。Domain は internal で読み込み、公開する部分に
        // Domain の型を出せないようにする (Domain を使う初期化などは、同じパッケージの組み立てだけが使える package にする)
        .target(
            name: "RegzaPresentation",
            dependencies: ["RegzaDomain"],
            swiftSettings: [.enableUpcomingFeature("InternalImportsByDefault")]
        ),
        // 組み立てる場所 (Composition Root): どの Repository の実装を使うかを決めて AppViewModel を作る
        .target(name: "RegzaApp", dependencies: ["RegzaPresentation", "RegzaInfrastructure"]),
        // 見本の Repository (テレビにも録画サーバーにもつながない)
        .target(name: "RegzaSample", dependencies: ["RegzaDomain", "RegzaPresentation", "RegzaInfrastructure"]),
        .executableTarget(name: "RegzaCLI", dependencies: ["RegzaApp", "RegzaSample"]),
        .testTarget(
            name: "RegzaCoreTests",
            dependencies: ["RegzaApp", "RegzaSample", "RegzaPresentation", "RegzaDomain", "RegzaInfrastructure", "RegzaSharedModels"]),
    ]
)
