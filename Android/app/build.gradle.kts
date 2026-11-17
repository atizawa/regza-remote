import java.util.zip.ZipFile

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.regzaremote"
    compileSdk = 37
    // APK に入れる Swift の .so のシンボルを落とすときに使う NDK (core:bridge の Swift のビルドと同じ版)。
    // 指定がないと落とせずに、手元のフォルダの場所などが残ったまま入る
    ndkVersion = libs.versions.ndk.get()

    defaultConfig {
        applicationId = "com.example.regzaremote"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Swift の .so は arm64 だけ作っている (buildSwift)
        ndk { abiFilters += "arm64-v8a" }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    buildTypes {
        release {
            // Java のコードを縮める (Compose などのライブラリのうち、使っていない部分を外す)
            isMinifyEnabled = true
            isShrinkResources = true
            // Swift のつなぎを残す決まりは core:bridge が渡す (consumer-rules.pro)
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    // swift-java が作る Java のコードは Java 17 の書き方を使う (RegzaAndroid/swift-java.common.config の javaSourceLevel)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

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
    // Swift の窓口とつなぎ (Swift の .so・swift-java が作る Java のクラス・画面の送り先と state の Flow)
    implementation(project(":core:bridge"))
    // 色・余白・テーマ
    implementation(project(":core:design"))
    // 文言 (String Catalog から生成)
    implementation(project(":core:localization"))
    // 機能の画面が共通に使う部品と、画面のプレビューの準備
    implementation(project(":core:ui"))
    // 機能の画面。組み立て (ui.app) がつなぐ
    listOf("remote", "player", "guide", "program", "channels", "reservations", "settings").forEach {
        implementation(project(":feature:$it"))
    }
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
