// swift-tools-version: 6.0
import PackageDescription

// iOS と Android で共有するもの。Foundation のみに依存し、Swift SDK for Android でもビルドできるようにする:
// キーコード、HTTP/Digest 認証クライアント、status 解析、RegzaRemote (切り替え中の問い合わせを防ぐしくみ) など。
// iOS だけのものは iOS/RegzaKit、Android だけのものは Android/RegzaAndroid に置く
let package = Package(
    name: "RegzaCore",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        .library(name: "RegzaCore", targets: ["RegzaCore"]),
    ],
    targets: [
        .target(name: "RegzaCore"),
        .testTarget(name: "RegzaCoreTests", dependencies: ["RegzaCore"]),
    ]
)
