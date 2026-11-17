// src/main/kotlin の regza.android.*.gradle.kts が、モジュールに付ける決まりになる (precompiled script plugin)
plugins {
    `kotlin-dsl`
}

dependencies {
    // 使うモジュールでは、ルートの build.gradle.kts が読み込んだ同じ版のプラグインを使う
    compileOnly(libs.android.gradlePlugin)
    compileOnly(libs.compose.gradlePlugin)
}
