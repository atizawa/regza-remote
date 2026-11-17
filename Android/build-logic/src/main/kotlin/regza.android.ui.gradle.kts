// 機能の画面のモジュール (ui/<機能>) の共通の決まり。名前空間はフォルダの名前から決め、
// 共通の部品 (ui:common) と、画面のファイルの末尾のプレビューに要るものを入れる。ほかの機能とアプリの組み立ては読み込まない
import com.android.build.api.dsl.LibraryExtension

plugins {
    id("regza.android.compose")
}

val libraries = extensions.getByType<VersionCatalogsExtension>().named("libs")

extensions.configure<LibraryExtension> {
    namespace = "com.example.regzaremote.ui.${project.name}"
}

dependencies {
    "implementation"(project(":ui:common"))
    "implementation"(libraries.findLibrary("androidx-compose-material-icons-core").get())
    "implementation"(libraries.findLibrary("androidx-compose-ui-tooling-preview").get())
    "debugImplementation"(libraries.findLibrary("androidx-compose-ui-tooling").get())
}
