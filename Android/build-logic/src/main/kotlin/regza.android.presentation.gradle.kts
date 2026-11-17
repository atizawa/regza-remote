// 画面の状態と操作の型のモジュール (presentation/<名前>) の共通の決まり。共有の Swift のプレゼンテーションのモジュール
// (PresentationCore・<機能>Presentation・AppPresentation) と 1 対 1 に対応し、その型の Java のクラスと、
// 画面が受け取る送り先 (<接頭辞>Send)・プレビューが受け取るアプリ (<接頭辞>App) を入れる (どれも Swift のビルドで作る)。
// 共通 (core) 以外は共通だけに依存し、ほかの機能を読み込まない
import com.android.build.api.dsl.LibraryExtension

plugins {
    id("regza.android.library")
}

extensions.configure<LibraryExtension> {
    namespace = "com.example.regzaremote.presentation.${project.name}"
    // build-swift が Swift のモジュールごとに分けた Java のクラスと、ScreenGlue が作った Kotlin
    sourceSets.getByName("main").java.srcDirs(rootDir.resolve(".build/swift/presentation-java/${project.name}"))
    sourceSets.getByName("main").kotlin.srcDirs(rootDir.resolve(".build/swift/screen-glue-kotlin/${project.name}"))
}

// 作られたソースは Swift のビルド (core:bridge の buildSwift) で作られるので、その後でビルドする
tasks.named("preBuild") { dependsOn(":core:bridge:buildSwift") }

if (project.name != "core") {
    dependencies {
        "api"(project(":presentation:core"))
    }
}
