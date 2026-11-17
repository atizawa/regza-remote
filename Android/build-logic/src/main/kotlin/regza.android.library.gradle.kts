// Android のライブラリのモジュール (core・feature) の共通の決まり: SDK と Java の版
import com.android.build.api.dsl.LibraryExtension

plugins {
    id("com.android.library")
}

val versions = extensions.getByType<VersionCatalogsExtension>().named("libs")

extensions.configure<LibraryExtension> {
    compileSdk = versions.findVersion("androidCompileSdk").get().requiredVersion.toInt()
    defaultConfig {
        minSdk = versions.findVersion("androidMinSdk").get().requiredVersion.toInt()
    }
    // swift-java が作る Java のコードは Java 17 の書き方を使う (RegzaAndroid/swift-java.common.config の javaSourceLevel)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
