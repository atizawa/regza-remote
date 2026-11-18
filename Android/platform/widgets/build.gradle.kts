// ホーム画面のウィジェット (iOS の Widgets に対応)。キーのボタンの操作は画面のない入口 (systemactions) に任せる。
// アプリの組み立て (appservices) と Swift の窓口は読み込まない
plugins {
    id("regza.android.compose")
}

android {
    namespace = "com.example.regzaremote.widgets"
}

dependencies {
    implementation(project(":platform:systemactions"))
    // キーの型 (RegzaKey)
    implementation(project(":presentation:core"))
    // キーのアイコン (通知と共通)
    implementation(project(":core:design"))
    implementation(project(":core:localization"))
    implementation(libs.androidx.glance.appwidget)
}
