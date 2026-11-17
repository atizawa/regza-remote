// 文言。String Catalog (../../Localization) から生成した文字列リソースと、Compose から引く AppStrings、
// 共有の Swift に渡す文言 (CoreStringResources)。アプリのほかの部分は知らない
plugins {
    id("regza.android.compose")
}

android {
    namespace = "com.example.regzaremote.localization"
}

dependencies {
    implementation(libs.androidx.compose.ui)
}
