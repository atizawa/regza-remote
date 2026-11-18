// 画面のない入口 (ウィジェットのボタン) からの操作 (iOS の SystemActions に対応)。アプリと同じ保存先・認証・通信でキーを送る
plugins {
    id("regza.android.library")
}

android {
    namespace = "com.example.regzaremote.systemactions"
}

dependencies {
    implementation(project(":platform:appservices"))
    implementation(project(":core:localization"))
    // ウィジェットのボタンから呼ばれる操作 (ActionCallback)
    api(libs.androidx.glance.appwidget)
}
