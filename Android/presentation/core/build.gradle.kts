// 共通の型: iOS と共有の UI の型 (RegzaSharedModels) と、共通のプレゼンテーション (PresentationCore) の状態と操作の型、
// 画面の移り変わりの窓口 (AppNavigator)。どの画面のモジュールも使う
plugins {
    id("regza.android.presentation")
}

android {
    // iOS と共有の UI の型の Java のクラス (build-swift が作る)
    sourceSets.getByName("main").java.srcDirs(rootDir.resolve(".build/swift/regzashared-java"))
}

dependencies {
    // swift-java が作ったクラスが使う Java 側。型の一部なので、使う側にも見せる
    api(project(":swiftkit-core"))
    // state の購読 (Flow) に使う
    api(libs.kotlinx.coroutines.android)
}
