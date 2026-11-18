// 機能の画面が共通に使う部品 (見出し・ボタン・state の購読・権限の案内など) と、画面のプレビューの準備。
// 機能の画面とアプリの組み立ては知らない。アプリの仕組み (Live Updates など) は、受け口を置いてアプリが渡す
plugins {
    id("regza.android.compose")
}

android {
    namespace = "com.example.regzaremote.uicommon"

    defaultConfig {
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
        buildConfig = true
    }
}

dependencies {
    // 共通の型と送り先 (共通の presentation)・色と余白・文言は、画面を作るときにいつも一緒に使うので、使う側にも見せる。
    // Swift の窓口 (core:bridge) はプレビューの準備だけが使い、機能の画面には見せない (機能の画面は自分の機能の presentation だけを使う)
    api(project(":presentation:core"))
    // ロック画面と通知の表示 (Live Updates) のオン・オフの型。設定の画面のスイッチが使う (iOS の UICommon が LiveActivity を読み込むのと同じ向き)。
    // 機能の画面には見せない (実装を渡す組み立てだけが、自分で読み込む)
    implementation(project(":platform:liveupdate"))
    implementation(project(":core:bridge"))
    api(project(":core:design"))
    api(project(":core:localization"))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material.icons.core)
    implementation(libs.androidx.lifecycle.runtime.compose)
}
