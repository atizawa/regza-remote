// swift-tools-version: 6.0
import PackageDescription

// iOS と Android で共有するもの。Foundation のみに依存し、Swift SDK for Android でもビルドできるようにする。
// Clean Architecture の層ごとにモジュールを分け、依存の向き (Presentation → Domain ← Infrastructure) をコンパイラに守らせる。
// iOS だけのものは iOS/RegzaKit、Android だけのものは Android/RegzaAndroid に置く。
// regza は Mac で ViewModel を動かす CLI (CLI や AI のエージェントが、画面を通さずに状態を読んで操作する)
let package = Package(
    name: "RegzaCore",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "RegzaCore", targets: ["RegzaCore"]),
        .executable(name: "regza", targets: ["RegzaCLI"]),
    ],
    targets: [
        // Domain: アプリの中心になる型 (Data)、保存先などの protocol (Repositories)、決まりごと (UseCases)。ほかの層に依存しない
        .target(name: "RegzaDomain"),
        // Infrastructure: テレビ・Mirakurun・EPGStation との通信、HTTP、暗号、通信の形から Domain の型への変換 (Mappers)
        .target(name: "RegzaInfrastructure", dependencies: ["RegzaDomain"]),
        // Presentation: iOS と Android で共有する ViewModel。Infrastructure を直接使っているところは、Repository に置き換えていく
        .target(name: "RegzaCore", dependencies: ["RegzaDomain", "RegzaInfrastructure"]),
        .executableTarget(name: "RegzaCLI", dependencies: ["RegzaCore"]),
        .testTarget(name: "RegzaCoreTests", dependencies: ["RegzaCore", "RegzaDomain", "RegzaInfrastructure"]),
    ]
)
