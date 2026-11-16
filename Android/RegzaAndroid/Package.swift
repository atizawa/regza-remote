// swift-tools-version: 6.0
import PackageDescription

// Android アプリから RegzaCore (iOS と共有) を使うための Swift のライブラリ。窓口 (状態と操作) は ../RegzaAndroidBridge にあり、
// ここには Android 専用の部品 (MainActor を Looper で動かす・ユーザー ID) と、Java のつなぎを置く。
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
        // debug の APK が読み込む共有ライブラリ。本番のものに、偽物のテレビ・録画サーバーで組み立てる入口 (プレビュー・端末のテスト用) を足す。
        // build-swift が libRegzaAndroid.so の名前で debug の置き場に入れる (本番の .so には偽物を入れない)
        .library(name: "RegzaAndroidDebug", type: .dynamic, targets: ["RegzaAndroid", "RegzaAndroidFakesJava"]),
        // 窓口とつなぎを、ホストの JVM で動かす振る舞いのテスト (behavior-tests) から読み込むライブラリ。
        // Android 専用の部品 (Looper) は含めない
        .library(name: "RegzaJVMHost", type: .dynamic, targets: ["RegzaAndroidBridgeJava", "RegzaAndroidFakesJava"]),
        // テスト専用: APK の ICU の結果を確かめる。debug の APK にだけ入れる (本番の RegzaAndroid には入れない)
        .library(name: "RegzaFoundationCheck", type: .dynamic, targets: ["RegzaFoundationCheck"]),
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
        // 画面の状態と操作の型 (RegzaPresentation の State/・Action/ に置いた型) の Java のつなぎ。
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
        // 偽物で組み立てる入口 (RegzaAndroidBridge の RegzaAndroidFakes) の Java のつなぎ。debug の .so とホストの JVM 向けにだけ入れる
        // (設定は RegzaAndroidFakes.swift-java.config)
        .target(
            name: "RegzaAndroidFakesJava",
            dependencies: [
                "RegzaAndroidBridgeJava",
                .product(name: "RegzaAndroidFakes", package: "RegzaAndroidBridge"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "RegzaFoundationCheck",
            dependencies: [
                .product(name: "FoundationCheck", package: "RegzaAndroidBridge"),
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Android のメインスレッドの Looper で MainActor を動かすための宣言 (NDK の Looper と libdispatch)
        .target(
            name: "CAndroidMainLoop",
            linkerSettings: [.linkedLibrary("android")]
        ),
        .target(
            name: "RegzaAndroid",
            dependencies: [
                .product(name: "RegzaAndroidBridge", package: "RegzaAndroidBridge"),
                "CAndroidMainLoop",
                "RegzaSharedJava",
                "RegzaAndroidBridgeJava",
                .product(name: "SwiftJava", package: "swift-java"),
            ],
            exclude: ["swift-java.config"],
            // 作られるつなぎのコードが Swift 6 の厳しい並行性の検査に合わせていないので、5 のモードにする
            swiftSettings: [.swiftLanguageMode(.v5)],
            plugins: [.plugin(name: "JExtractSwiftPlugin", package: "swift-java")]
        ),
    ]
)
