// swift-tools-version: 6.0
import PackageDescription

// iOS と Android で共有するもの。Foundation のみに依存し、Swift SDK for Android でもビルドできるようにする:
// キーコード、HTTP/Digest 認証クライアント、status 解析、RegzaRemote (切り替え中の問い合わせを防ぐしくみ) など。
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
        .target(name: "RegzaCore"),
        .executableTarget(name: "RegzaCLI", dependencies: ["RegzaCore"]),
        .testTarget(name: "RegzaCoreTests", dependencies: ["RegzaCore"]),
    ]
)
