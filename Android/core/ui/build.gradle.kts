// 機能の画面が共通に使う部品 (見出し・ボタン・state の購読・権限の案内など) と、画面のプレビューの準備。
// 機能の画面とアプリの組み立ては知らない。アプリの仕組み (Live Updates など) は、受け口を置いてアプリが渡す
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.regzaremote.uicommon"
    compileSdk = 37

    defaultConfig {
        minSdk = 28
        // エディタの横のプレビュー (ホストの JVM) が読み込む Swift のライブラリの場所 (FakeApps)。
        // 手元のフォルダの場所なので、配るアプリ (release) には入れず、debug のビルドでだけ入れる
        buildConfigField("String", "HOST_SWIFT_LIBRARIES", "\"\"")
    }

    buildTypes {
        debug {
            // 振る舞いのテストと同じもの (behavior-tests の buildJvmHost が作る)。エディタの中でしか使わない
            buildConfigField("String", "HOST_SWIFT_LIBRARIES", "\"${rootDir.resolve(".build/jvm-host/libs").path}\"")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    // Swift のつなぎ (state の型と購読)・色と余白・文言は、画面を作るときにいつも一緒に使うので、使う側にも見せる
    api(project(":core:bridge"))
    api(project(":core:design"))
    api(project(":core:localization"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.lifecycle.runtime.compose)
}
