// swift-tools-version: 6.0
import PackageDescription

// Android アプリに見せる窓口 (RegzaAndroidApp と、その状態・操作の型)。共有の ViewModel の state を Android 向けに詰め直し、
// Android からの操作を ViewModel の操作に置き換える。Android 専用の部品 (Looper・BoringSSL・swift-java) は
// ../RegzaAndroid に置き、ここは Mac でもビルドできるようにして、swift test で窓口を確かめる。
// Java のクラスは mise run build-swift が swift-java のツールで作る (設定は ../RegzaAndroid/RegzaAndroidBridge.swift-java.config)
let package = Package(
    name: "RegzaAndroidBridge",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RegzaAndroidBridge", targets: ["RegzaAndroidBridge"])
    ],
    dependencies: [
        .package(path: "../../Packages/RegzaCore")
    ],
    targets: [
        .target(
            name: "RegzaAndroidBridge",
            dependencies: [
                .product(name: "RegzaApp", package: "RegzaCore"),
                // 見本の通信で組み立てる入口 (RegzaAndroidApp.sample。JVM のテストで使う)
                .product(name: "RegzaSample", package: "RegzaCore"),
            ],
            // swift-java が作るつなぎと同じく、5 のモードにする
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "RegzaAndroidBridgeTests",
            dependencies: ["RegzaAndroidBridge", .product(name: "RegzaApp", package: "RegzaCore")],
            // 窓口の非同期の関数 (Java の Future になる) を MainActor から呼ぶので、窓口と同じ 5 のモードにする
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
