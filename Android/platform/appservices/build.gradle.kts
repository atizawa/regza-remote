// アプリの組み立て (iOS の AppServices に対応)。プロセスに 1 つの Swift の窓口 (AppContainer)・画面の ViewModel の入れ物・
// 保存先 (Keystore・SharedPreferences)・通信 (OkHttp)・共有の Swift の文言の入れ方を受け持つ。画面と画面のない入口は読み込まない
plugins {
    id("regza.android.library")
}

android {
    namespace = "com.example.regzaremote.appservices"
    buildFeatures {
        buildConfig = true
    }
}

dependencies {
    // 組み立てた Swift の窓口を、使う側 (起動の画面・画面のない入口・Live Updates) に渡す
    api(project(":core:bridge"))
    implementation(project(":core:localization"))
    // プロセスを起こしたときに、ロック画面と通知の表示を見張り直す (iOS の AppServices が LiveActivity を使うのと同じ向き)
    implementation(project(":platform:liveupdate"))
    implementation(libs.okhttp)
    api(libs.androidx.lifecycle.viewmodel.compose)
}
