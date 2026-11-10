// swift-tools-version: 6.0
import PackageDescription

// Android アプリから RegzaCore (iOS と共有) を使うための Swift のライブラリ。窓口 (状態と操作) は ../RegzaAndroidBridge にあり、
// ここには Android 専用の部品 (MainActor を Looper で動かす・BoringSSL・ユーザー ID) と、Java のつなぎを置く。
// swift-java の JExtractSwiftPlugin が RegzaAndroid の public な関数から Java のクラスを作る
// (設定は Sources/RegzaAndroid/swift-java.config。mise run build-swift が共通の設定 swift-java.common.config から書き出す)。
// ビルドは Android/ で mise run build-swift (中身は scripts/build-swift.sh)。
// swift-java の設定は、どのモジュールにも共通のもの (swift-java.common.config) に、モジュールごとのもの (<モジュール>.swift-java.config) を重ねて使う
let package = Package(
    name: "RegzaAndroid",
    // swift-java に合わせる (Android 向けのビルドでは使われない)
    platforms: [.macOS(.v15)],
    products: [
        // Android アプリが System.loadLibrary("RegzaAndroid") で読み込む共有ライブラリ
        .library(name: "RegzaAndroid", type: .dynamic, targets: ["RegzaAndroid"]),
        // 窓口とつなぎを、Mac の JVM で動かす振る舞いのテスト (behavior-tests) から読み込むライブラリ。
        // Android 専用の部品 (Looper・BoringSSL) は含めない
        .library(name: "RegzaJVMHost", type: .dynamic, targets: ["RegzaAndroidBridgeJava"]),
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
        // (設定は共通の swift-java.common.config だけ)。ここにはプラグインをかけない
        .target(
            name: "RegzaSharedJava",
            dependencies: [
                .product(name: "RegzaSharedModels", package: "RegzaCore"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // 画面の状態と操作の型 (RegzaPresentation の ChannelListState など) の Java のつなぎ。
        // iOS と共有のパッケージにはプラグインをかけられないので、mise run build-swift が swift-java のツールで Generated/ に作る
        // (設定は RegzaPresentation.swift-java.config。Java にする型だけを並べる)
        .target(
            name: "RegzaPresentationJava",
            dependencies: [
                "RegzaSharedJava",
                .product(name: "RegzaPresentation", package: "RegzaCore"),
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
                "RegzaPresentationJava",
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
