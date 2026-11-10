// swift-tools-version: 6.0
import PackageDescription

// 画面ごとのフォルダの State/ と Action/ に置いた型から、Android の窓口のつなぎを作る道具 (screen-glue)。
// Swift のソースは swift-syntax で読む (文字の並びで探さないので、書き方が変わっても読み違えない)。
// Mac で動かす道具なので、アプリには入らない。mise run build-swift が毎回動かし、テストは作ったものが古くないかも確かめる
let package = Package(
    name: "ScreenGlue",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "screen-glue", targets: ["screen-glue"])
    ],
    dependencies: [
        // swift-java (RegzaAndroid) が使うものと同じ版にする
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "603.0.2")
    ],
    targets: [
        // つなぎを作る本体 (テストからも直接使う)
        .target(
            name: "ScreenGlueKit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .executableTarget(name: "screen-glue", dependencies: ["ScreenGlueKit"]),
        .testTarget(name: "ScreenGlueTests", dependencies: ["ScreenGlueKit"]),
    ]
)
