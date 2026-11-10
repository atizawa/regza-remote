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
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Swift の .so は arm64 だけ作っている (buildSwift)
        ndk { abiFilters += "arm64-v8a" }
        // エディタの横のプレビュー (Mac の JVM) が読み込む、Mac 向けの Swift のライブラリの場所 (SamplePreview)。
        // 手元のフォルダの場所なので、配るアプリ (release) には入れず、debug のビルドでだけ入れる
        buildConfigField("String", "MAC_SWIFT_LIBRARIES", "\"\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    buildTypes {
        debug {
            // 振る舞いのテストと同じもの (behavior-tests の buildJvmHost が作る)。エディタの中でしか使わない
            buildConfigField("String", "MAC_SWIFT_LIBRARIES", "\"${rootDir.resolve(".build/jvm-host/libs").path}\"")
        }
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
        // iOS と共有の型 (RegzaKey・ProgramItem など) の Java のクラス
        "../.build/swift/regzashared-java",
        // 画面の状態と操作の型 (ChannelListState など) の Java のクラス
        "../.build/swift/regzapresentation-java",
        // 窓口 (RegzaAndroidApp と、その状態・操作の型) の Java のクラス
        "../.build/swift/regzabridge-java",
    )
    // 画面が受け取る送り先 (Send) と、Swift の窓口に送る AppSend (scripts/generate-screen-glue.sh が作る)
    sourceSets.getByName("main").kotlin.srcDirs("../.build/swift/screen-glue-kotlin")
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
    inputs.files(fileTree(androidDir.resolve("RegzaAndroid")) {
        exclude(
            "Sources/RegzaSharedJava/Generated/**", "Sources/RegzaPresentationJava/Generated/**",
            "Sources/RegzaAndroidBridgeJava/Generated/**",
        )
    })
    inputs.files(fileTree(androidDir.resolve("RegzaAndroidBridge")) { include("Package.swift", "Sources/**") })
    inputs.file(androidDir.resolve("mise.toml"))
    inputs.dir(androidDir.resolve("scripts"))
    inputs.property("ndkVersion", android.ndkVersion)
    outputs.dir("src/main/jniLibs")
    outputs.dir(androidDir.resolve(".build/swift/regzashared-java"))
    outputs.dir(androidDir.resolve(".build/swift/regzapresentation-java"))
    outputs.dir(androidDir.resolve(".build/swift/regzabridge-java"))
    outputs.dir(androidDir.resolve(".build/swift/screen-glue-kotlin"))
    outputs.dir(androidDir.resolve(".build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java"))
    outputs.dir(androidDir.resolve(".build/swift/checkouts/swift-java/SwiftKitCore/src/main"))
}
tasks.named("preBuild") { dependsOn(buildSwift) }
// エディタの横のプレビューのために、debug のビルドでは Mac 向けの Swift のライブラリも作る (SamplePreview)
tasks.matching { it.name == "preDebugBuild" }.configureEach { dependsOn(":behavior-tests:buildJvmHost") }

dependencies {
    // swift-java が作ったクラスが使う Java 側
    implementation(project(":swiftkit-core"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.compose.ui)
    // 画面のプレビュー (それぞれの画面のファイルの末尾)。Swift の state を使うので、「Run Preview」でエミュレーターに出す。
    // ui-tooling はエミュレーターでプレビューを出す PreviewActivity を含むので、debug にだけ入れる
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    // ライブ視聴: EPGStation の HLS の配信を再生する
    implementation(libs.androidx.media3.exoplayer)
    implementation(libs.androidx.media3.exoplayer.hls)
    implementation(libs.androidx.media3.ui)
    // タブの中の画面の移り変わり: 共有の AppViewModel が持つ path を back stack として渡す
    implementation(libs.androidx.navigation3.runtime)
    implementation(libs.androidx.navigation3.ui)
    implementation(libs.kotlinx.coroutines.android)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.ext.junit)
}
