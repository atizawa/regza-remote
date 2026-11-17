// 機能の画面: 視聴 (視聴中の詳細・ミニプレーヤー・ライブ視聴)。共通の決まりは build-logic の regza.android.ui (共通の部品 ui:common だけを使う)
plugins {
    id("regza.android.ui")
}

dependencies {
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    // ライブ視聴: EPGStation の HLS の配信を再生する
    implementation(libs.androidx.media3.exoplayer)
    implementation(libs.androidx.media3.exoplayer.hls)
    implementation(libs.androidx.media3.ui)
}
