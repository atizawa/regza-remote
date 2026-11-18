// ロック画面と通知の表示 (Live Updates。iOS の LiveActivity に対応)。リモコンの state を読んで通知を出し、通知のボタンの操作を送る。
// アプリの組み立て (appservices) は読み込まず、Swift の窓口は起動時に渡してもらう (LiveUpdateController.install)
plugins {
    id("regza.android.library")
}

android {
    namespace = "com.example.regzaremote.liveupdate"
}

dependencies {
    implementation(project(":core:bridge"))
    // 通知のボタンのアイコン (ウィジェットと共通)。色と余白のモジュールは Compose の部品も見せるので、版を決める BOM も入れる
    implementation(project(":core:design"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(project(":core:localization"))
}
