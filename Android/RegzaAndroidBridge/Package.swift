// swift-tools-version: 6.0
import PackageDescription

// Android アプリに見せる窓口 (RegzaAndroidApp と、その状態・操作の型)。共有の ViewModel の state を Android 向けに詰め直し、
// Android からの操作を ViewModel の操作に置き換える。Android 専用の部品 (Looper・swift-java) は
// ../RegzaAndroid に置き、ここは Mac でもビルドできるようにして、swift test で窓口を確かめる。
// Java のクラスは mise run build-swift が swift-java のツールで作る (設定は ../RegzaAndroid/RegzaAndroidBridge.swift-java.config)
let package = Package(
    name: "RegzaAndroidBridge",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RegzaAndroidBridge", targets: ["RegzaAndroidBridge"]),
        // テスト専用: APK の ICU の結果を確かめる (debug の APK にだけ入る .so から使う。本番の窓口には入れない)
        .library(name: "FoundationCheck", targets: ["FoundationCheck"]),
        // 偽物のテレビ・録画サーバーで組み立てる入口。プレビューと JVM のテストだけが使い、debug の APK にだけ入る (本番の窓口には入れない)
        .library(name: "RegzaAndroidFakes", targets: ["RegzaAndroidFakes"]),
    ],
    dependencies: [
        .package(path: "../../Packages/RegzaCore")
    ],
    targets: [
        .target(
            name: "RegzaAndroidBridge",
            dependencies: [
                .product(name: "RegzaApp", package: "RegzaCore"),
                // 共有の Swift の文言に、Android の文字列リソースを入れる
                .product(name: "RegzaStrings", package: "RegzaCore"),
            ],
            // swift-java が作るつなぎと同じく、5 のモードにする
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "RegzaAndroidFakes",
            dependencies: [
                "RegzaAndroidBridge",
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "RegzaFakeServers", package: "RegzaCore"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(name: "FoundationCheck", dependencies: [.product(name: "RegzaStrings", package: "RegzaCore")]),
        .testTarget(name: "FoundationCheckTests", dependencies: ["FoundationCheck"]),
        .testTarget(
            name: "RegzaAndroidBridgeTests",
            dependencies: [
                "RegzaAndroidBridge",
                "RegzaAndroidFakes",
                .product(name: "RegzaApp", package: "RegzaCore"),
                .product(name: "RegzaStrings", package: "RegzaCore"),
            ],
            // 窓口の非同期の関数 (Java の Future になる) を MainActor から呼ぶので、窓口と同じ 5 のモードにする
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
