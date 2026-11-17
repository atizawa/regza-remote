// 機能の画面: 設定。共通の決まりは build-logic の regza.android.feature (共通の部品 core:ui だけを使う)
plugins {
    id("regza.android.feature")
}

dependencies {
    implementation(libs.androidx.activity.compose)
}
