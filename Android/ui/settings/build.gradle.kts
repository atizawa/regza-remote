// 機能の画面: 設定。共通の決まりは build-logic の regza.android.ui (共通の部品 ui:common だけを使う)
plugins {
    id("regza.android.ui")
}

dependencies {
    implementation(libs.androidx.activity.compose)
}
