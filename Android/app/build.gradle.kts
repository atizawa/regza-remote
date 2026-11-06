plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.regzaremote"
    compileSdk = 37
    // .so からデバッグ情報を取り除くのに NDK を使う (場所は mise.toml の ANDROID_NDK_HOME)
    ndkPath = providers.environmentVariable("ANDROID_NDK_HOME").get()
    ndkVersion = "30.0.16248370" // r30

    defaultConfig {
        applicationId = "com.example.regzaremote"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
        // Swift の .so は arm64 だけ作っている (mise run build-swift)
        ndk { abiFilters += "arm64-v8a" }
    }

    buildFeatures { compose = true }

    // swift-java が作る Java のコードは Java 17 の書き方を使う (swift-java.config の javaSourceLevel)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // swift-java が RegzaAndroid の Swift から作った Java のクラス (mise run build-swift で作られる)
    sourceSets.getByName("main").java.srcDirs(
        "../.build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java",
        // RegzaCore の型 (RegzaKey など) の Java のクラス
        "../.build/swift/regzacore-java",
    )
}

dependencies {
    // swift-java が作ったクラスが使う Java 側
    implementation(project(":swiftkit-core"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.kotlinx.coroutines.android)
}
