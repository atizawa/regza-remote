// swift-tools-version: 6.0
import PackageDescription

// Android アプリから RegzaCore (iOS と共有) を使うための Swift のライブラリ。窓口 (状態と操作) は ../RegzaAndroidBridge にあり、
// ここには Android 専用の部品 (MainActor を Looper で動かす・BoringSSL・ユーザー ID) と、Java のつなぎを置く。
// swift-java の JExtractSwiftPlugin が RegzaAndroid の public な関数から Java のクラスを作る
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
        .package(path: "../../Packages/RegzaCore"),
        .package(path: "../RegzaAndroidBridge"),
        // まだ 1.0 前でリリースのタグがないので、確かめたコミットに固定する。
        // Java 側の SwiftKitCore も、SwiftPM が取ってきたこの版のソースを app のビルドに含める
        .package(url: "https://github.com/swiftlang/swift-java", revision: "301e3da710ede7af93e798f1ce1c7950715a5748"),
    ],
    targets: [
        // iOS と共有の UI の型 (RegzaSharedModels) の Java のつなぎ。iOS と共有の Packages/RegzaCore には
        // プラグインをかけられないので、mise run build-swift が swift-java のツールで Generated/ に作る
        // (設定は RegzaSharedModels.swift-java.config)。ここにはプラグインをかけない
        .target(
            name: "RegzaSharedJava",
            dependencies: [
                .product(name: "RegzaSharedModels", package: "RegzaCore"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // 窓口 (RegzaAndroidBridge) の Java のつなぎ。別のパッケージにあってプラグインをかけられないので、
        // mise run build-swift が swift-java のツールで Generated/ に作る (設定は RegzaAndroidBridge.swift-java.config)
        .target(
            name: "RegzaAndroidBridgeJava",
            dependencies: [
                "RegzaSharedJava",
                .product(name: "RegzaAndroidBridge", package: "RegzaAndroidBridge"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // SDK に入っている BoringSSL の関数の宣言 (HTTPS で使う)。ライブラリの場所は build-swift がリンカーに渡す
        .target(
            name: "CBoringSSL",
            linkerSettings: [.linkedLibrary("ssl"), .linkedLibrary("crypto")]
        ),
        // Android のメインスレッドの Looper で MainActor を動かすための宣言 (NDK の Looper と libdispatch)
        .target(
            name: "CAndroidMainLoop",
            linkerSettings: [.linkedLibrary("android")]
        ),
        .target(
            name: "RegzaAndroid",
            dependencies: [
                "CAndroidMainLoop",
                "CBoringSSL",
                "RegzaSharedJava",
                "RegzaAndroidBridgeJava",
                // 通信の差し替えとユーザー ID に使う
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            exclude: ["swift-java.config"],
            // 作られるつなぎのコードが Swift 6 の厳しい並行性の検査に合わせていないので、5 のモードにする
            swiftSettings: [.swiftLanguageMode(.v5)],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
    ]
)
