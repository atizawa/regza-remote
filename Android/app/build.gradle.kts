import java.util.zip.ZipFile

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
        // エディタの横のプレビュー (ホストの JVM) が読み込む Swift のライブラリの場所 (SamplePreview)。
        // 手元のフォルダの場所なので、配るアプリ (release) には入れず、debug のビルドでだけ入れる
        buildConfigField("String", "HOST_SWIFT_LIBRARIES", "\"\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    buildTypes {
        debug {
            // 振る舞いのテストと同じもの (behavior-tests の buildJvmHost が作る)。エディタの中でしか使わない
            buildConfigField("String", "HOST_SWIFT_LIBRARIES", "\"${rootDir.resolve(".build/jvm-host/libs").path}\"")
        }
        release {
            // Java のコードを縮める (Compose などのライブラリのうち、使っていない部分を外す)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // swift-java が作る Java のコードは Java 17 の書き方を使う (RegzaAndroid/swift-java.common.config の javaSourceLevel)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // swift-java が RegzaAndroid の Swift から作った Java のクラス (buildSwift で作られる)
    sourceSets.getByName("main").java.srcDirs(
        "../.build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java",
        // iOS と共有の型 (RegzaSharedModels) の Java のクラス
        "../.build/swift/regzashared-java",
        // 画面の状態と操作の型 (RegzaPresentation の State/・Action/ に置いた型) の Java のクラス
        "../.build/swift/regzapresentation-java",
        // 窓口 (RegzaAndroidApp と、その状態・操作の型) の Java のクラス
        "../.build/swift/regzabridge-java",
    )
    // 偽物のテレビ・録画サーバーで組み立てる入口 (RegzaFakeApp) の Java のクラス。debug だけに入れる (本番の .so にもない)
    sourceSets.getByName("debug").java.srcDirs("../.build/swift/regzafakes-java")
    // 画面が受け取る送り先 (Send) と、Swift の窓口に送る AppSend (Android/ScreenGlue の screen-glue が作る)
    sourceSets.getByName("main").kotlin.srcDirs("../.build/swift/screen-glue-kotlin")
}

// Swift の .so と、swift-java が作る Java のクラスを作る (mise run build-swift)。
// app と swiftkit-core (swift-java のソースを使う) のビルドの前に動く。Swift のソースや設定が変わったときだけ動く
val buildSwift = tasks.register<Exec>("buildSwift") {
    description = "mise run build-swift で、Swift の .so と swift-java の Java のクラスを作る"
    val androidDir = rootDir
    workingDir = androidDir
    // mise の場所はルートの build.gradle.kts で探す。mise の環境に既に別の Swift があると PATH の順番を直さない場合があるため、
    // build-swift が `mise which swift` の実体を直接選べるよう、mise 自身の場所も渡す
    val mise = rootProject.extra["mise"] as String
    commandLine(mise, "run", "build-swift")
    environment("MISE_EXECUTABLE", mise)
    // Gradle と同じ SDK の場所と ndkVersion を渡す。Android Gradle Plugin は場所を聞くだけでは NDK を入れないので、
    // なければ build-swift が入れる
    val sdk = androidComponents.sdkComponents.sdkDirectory
    environment("NDK_VERSION", android.ndkVersion)
    // ICU はデータを日本語・英語に絞って作り直す。比べるときは -PregzaFullICU=true で元のまま入れる。
    // 環境変数ではなくプロパティで受け取り、作り直しの判断にも含める (常駐の Gradle に環境変数が届かず、切り替えても飛ばされないように)
    val fullICU = providers.gradleProperty("regzaFullICU").map { it.toBoolean() }.getOrElse(false)
    environment("REGZA_FULL_ICU", if (fullICU) "1" else "0")
    inputs.property("regzaFullICU", fullICU)
    doFirst { environment("ANDROID_HOME", sdk.get().asFile.path) }

    inputs.files(fileTree(androidDir.resolve("../Packages/RegzaCore")) { include("Package.swift", "Sources/**", "Plugins/**", "Tools/**") })
    inputs.files(fileTree(androidDir.resolve("../OpenAPI")) { include("regza-tv.yaml", "mirakurun.json", "epgstation.json") })
    inputs.files(
        fileTree(androidDir.resolve("RegzaAndroid")) {
            exclude(
                "Sources/RegzaSharedJava/Generated/**",
                "Sources/RegzaPresentationJava/Generated/**",
                "Sources/RegzaAndroidBridgeJava/Generated/**",
                "Sources/RegzaAndroidFakesJava/Generated/**",
                // build-swift が共通の設定から書き出すもの
                "Sources/RegzaAndroid/swift-java.config",
            )
        },
    )
    inputs.files(fileTree(androidDir.resolve("RegzaAndroidBridge")) { include("Package.swift", "Sources/**") })
    inputs.file(androidDir.resolve("mise.toml"))
    inputs.file(androidDir.resolve("../toolchains.toml"))
    inputs.dir(androidDir.resolve("scripts"))
    // 窓口のつなぎを作る道具
    inputs.files(fileTree(androidDir.resolve("ScreenGlue")) { include("Package.swift", "Package.resolved", "Sources/**") })
    inputs.property("ndkVersion", android.ndkVersion)
    outputs.dir("src/main/jniLibs")
    // 本番の libRegzaAndroid.so と、偽物の入口とテスト専用の .so を足した debug のもの
    outputs.dir("src/release/jniLibs")
    outputs.dir("src/debug/jniLibs")
    outputs.dir(androidDir.resolve(".build/swift/regzashared-java"))
    outputs.dir(androidDir.resolve(".build/swift/regzapresentation-java"))
    outputs.dir(androidDir.resolve(".build/swift/regzabridge-java"))
    outputs.dir(androidDir.resolve(".build/swift/regzafakes-java"))
    outputs.dir(androidDir.resolve(".build/swift/screen-glue-kotlin"))
    outputs.dir(
        androidDir.resolve(".build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java"),
    )
    outputs.dir(androidDir.resolve(".build/swift/checkouts/swift-java/SwiftKitCore/src/main"))
    // swift-java が作る Swift のつなぎ (Git に入れていない)。消えたら作り直す (behavior-tests の buildJvmHost もこれを使う)
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaSharedJava/Generated"))
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaPresentationJava/Generated"))
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated"))
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaAndroidFakesJava/Generated"))
    outputs.file(androidDir.resolve("RegzaAndroid/Sources/RegzaAndroid/swift-java.config"))
}
tasks.named("preBuild") { dependsOn(buildSwift) }
// 配るアプリ (release の APK) に、手元のフォルダの場所 (ホームのフォルダ) が残っていないことを確かめる。
// ビルドの設定やソースの #filePath などから入ると、開発している人のユーザー名やフォルダの構成が配られてしまう。
// release のビルドのたびに、APK の中のすべてのファイル (Java のクラス・Swift の .so・リソース) を調べる
val checkReleaseApk = tasks.register("checkReleaseApk") {
    description = "release の APK に、手元のフォルダの場所と、偽物・プレビューの準備が入っていないことを確かめる"
    val apks = layout.buildDirectory.dir("outputs/apk/release")
    val home = System.getProperty("user.home")
    // /root.res のような ICU のリソース名を、/root のホームパスと誤認しない。
    val homePath = Regex("${Regex.escape(home)}(?![\\p{L}\\p{N}_.-])")
    // 偽物 (Swift の RegzaFakeServers・RegzaAndroidFakes、Java の RegzaFakeApp) と、プレビューが名前で探す debug の FakeApps。
    // 本番の .so は build-swift が、プレビューの関数は縮小が取り除く。取り除かれていることをここで確かめる
    val fakeMarker = Regex("RegzaFakeServers|RegzaAndroidFakes|RegzaFakeApp|appservices\\.preview\\.FakeApps")
    inputs.dir(apks)
    doLast {
        val files = apks.get().asFile.listFiles { file -> file.extension == "apk" }.orEmpty()
        check(files.isNotEmpty()) { "release の APK が見つかりません: ${apks.get().asFile}" }
        for (apk in files) {
            ZipFile(apk).use { zip ->
                val found = mutableListOf<String>()
                val fakes = mutableListOf<String>()
                // 1 つずつ読んで調べる (大きな .so をまとめて持たない)。バイト列のまま探すため、1 バイトを 1 文字にする
                // ISO-8859-1 で読む (ホームのフォルダの名前と偽物の名前は ASCII)
                for (entry in zip.entries()) {
                    val content = String(zip.getInputStream(entry).use { it.readBytes() }, Charsets.ISO_8859_1)
                    if (homePath.containsMatchIn(content)) found += entry.name
                    if (fakeMarker.containsMatchIn(content)) fakes += entry.name
                }
                check(found.isEmpty()) { "${apk.name} に手元のフォルダの場所 ($home) が入っています: $found" }
                check(fakes.isEmpty()) { "${apk.name} に偽物かプレビューの準備が入っています: $fakes" }
            }
        }
    }
}
tasks.matching { it.name == "assembleRelease" }.configureEach { finalizedBy(checkReleaseApk) }
// ホスト向けライブラリは mise run prepare-android-preview で別途作る。APK のビルドには不要。

dependencies {
    implementation(libs.androidx.glance.appwidget)
    implementation(libs.okhttp)
    androidTestImplementation(libs.okhttp.mockwebserver)
    // swift-java が作ったクラスが使う Java 側
    implementation(project(":swiftkit-core"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.compose.ui)
    // 画面のプレビュー (それぞれの画面のファイルの末尾)。Swift の state を使うので、「Run Preview」でエミュレーターに出す
    // (偽物は debug にだけあり、プレビューの関数は release の縮小で取り除かれる)。
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
    androidTestImplementation(libs.androidx.test.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
