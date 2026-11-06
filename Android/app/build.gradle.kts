plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.regzaremote"
    compileSdk = 37
    // NDK の版はここだけで決める。Swift の .so のビルド (buildSwift) に渡し、Android SDK の ndk/<版> になければ
    // build-swift が入れる。Swift SDK for Android が求める版 (r30) にする
    ndkVersion = "30.0.16248370"

    defaultConfig {
        applicationId = "com.example.regzaremote"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
        // Swift の .so は arm64 だけ作っている (buildSwift)
        ndk { abiFilters += "arm64-v8a" }
    }

    buildFeatures { compose = true }

    buildTypes {
        release {
            // Java のコードを縮める (Compose などのライブラリのうち、使っていない部分を外す)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // swift-java が作る Java のコードは Java 17 の書き方を使う (swift-java.config の javaSourceLevel)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // swift-java が RegzaAndroid の Swift から作った Java のクラス (buildSwift で作られる)
    sourceSets.getByName("main").java.srcDirs(
        "../.build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java",
        // RegzaCore の型 (RegzaKey など) の Java のクラス
        "../.build/swift/regzacore-java",
    )
}

// Swift の .so と、swift-java が作る Java のクラスを作る (mise run build-swift)。
// app と swiftkit-core (swift-java のソースを使う) のビルドの前に動く。Swift のソースや設定が変わったときだけ動く
val buildSwift = tasks.register<Exec>("buildSwift") {
    description = "mise run build-swift で、Swift の .so と swift-java の Java のクラスを作る"
    val androidDir = rootDir
    workingDir = androidDir
    // Android Studio から動かすと PATH に mise がないことがあるので、よく入っている場所から探す
    val mise = listOf("/opt/homebrew/bin/mise", "/usr/local/bin/mise", "${System.getProperty("user.home")}/.local/bin/mise")
        .firstOrNull { File(it).canExecute() } ?: "mise"
    commandLine(mise, "run", "build-swift")
    // Gradle と同じ SDK の場所と ndkVersion を渡す。Android Gradle Plugin は場所を聞くだけでは NDK を入れないので、
    // なければ build-swift が入れる
    val sdk = androidComponents.sdkComponents.sdkDirectory
    environment("NDK_VERSION", android.ndkVersion)
    doFirst { environment("ANDROID_HOME", sdk.get().asFile.path) }

    inputs.files(fileTree(androidDir.resolve("../Packages/RegzaCore")) { include("Package.swift", "Sources/**") })
    inputs.files(fileTree(androidDir.resolve("RegzaAndroid")) { exclude("Sources/RegzaCoreJava/Generated/**") })
    inputs.file(androidDir.resolve("mise.toml"))
    inputs.property("ndkVersion", android.ndkVersion)
    outputs.dir("src/main/jniLibs")
    outputs.dir(androidDir.resolve(".build/swift/regzacore-java"))
    outputs.dir(androidDir.resolve(".build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java"))
    outputs.dir(androidDir.resolve(".build/swift/checkouts/swift-java/SwiftKitCore/src/main"))
}
tasks.named("preBuild") { dependsOn(buildSwift) }

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
