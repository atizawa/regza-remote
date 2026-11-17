// 色・余白・テーマ。デザイントークン (../../Design) から生成した値と、それを Compose と View の両方で使う形にする。
// アプリのほかの部分 (画面・つなぎ) は知らない
plugins {
    id("regza.android.compose")
}

android {
    namespace = "com.example.regzaremote.design"
}

dependencies {
    implementation(libs.androidx.activity.compose)
    api(libs.androidx.compose.material3)
    api(libs.androidx.compose.ui)
}
