// swift-tools-version: 6.0
import PackageDescription

// Android アプリから RegzaCore (iOS と共有) を使うための Swift の公開 API。
// swift-java の JExtractSwiftPlugin が、ここの public な型と関数から Java のクラスと JNI のつなぎを作る
// (設定は Sources/RegzaAndroid/swift-java.config)。ビルドは Android/ で mise run build-swift
let package = Package(
    name: "RegzaAndroid",
    // swift-java に合わせる (Android 向けのビルドでは使われない)
    platforms: [.macOS(.v15)],
    products: [
        // Android アプリが System.loadLibrary("RegzaAndroid") で読み込む共有ライブラリ
        .library(name: "RegzaAndroid", type: .dynamic, targets: ["RegzaAndroid"]),
    ],
    dependencies: [
        .package(path: "../../Packages/RegzaKit"),
        // まだ 1.0 前でリリースのタグがないので、確かめたコミットに固定する。
        // Java 側の SwiftKitCore も、SwiftPM が取ってきたこの版のソースを app のビルドに含める
        .package(url: "https://github.com/swiftlang/swift-java", revision: "301e3da710ede7af93e798f1ce1c7950715a5748"),
    ],
    targets: [
        .target(
            name: "RegzaAndroid",
            dependencies: [
                .product(name: "RegzaCore", package: "RegzaKit"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            exclude: ["swift-java.config"],
            // 作られるつなぎのコードが Swift 6 の厳しい並行性の検査に合わせていないので、5 のモードにする
            swiftSettings: [.swiftLanguageMode(.v5)],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
    ]
)
