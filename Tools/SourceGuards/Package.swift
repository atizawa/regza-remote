// swift-tools-version: 6.0
import PackageDescription

// 型やモジュールの依存では守れない決まりを、リポジトリの Swift のソースを読んで見張る道具 (テストだけ)。
// ソースは swift-syntax で読む (文字の並びで探さないので、書き方が変わっても読み違えない)。
// ホストで動かす道具なので、アプリには入らない。共有の Swift (Android でもビルドする) に swift-syntax を入れないよう、別のパッケージにする
let package = Package(
    name: "SourceGuards",
    platforms: [.macOS(.v14)],
    dependencies: [
        // つなぎを作る道具 (Android/ScreenGlue) と同じ版にする
        .package(url: "https://github.com/swiftlang/swift-syntax", exact: "603.0.2")
    ],
    targets: [
        // ソースを読む部品と、決まりごとの見張り (テストから使う)
        .target(
            name: "SourceGuards",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(name: "SourceGuardsTests", dependencies: ["SourceGuards"]),
    ]
)
