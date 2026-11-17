// 機能の画面のモジュール (ui/<機能>) の共通の決まり。名前空間はフォルダの名前から決め、
// 共通の部品 (ui:common)・同じ名前の機能の状態と操作の型 (presentation/<機能>。なければ共通のものだけ)・
// 画面のファイルの末尾のプレビューに要るものを入れる。ほかの機能・Swift の窓口・アプリの組み立ては読み込まない
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
    if (rootDir.resolve("presentation/${project.name}/build.gradle.kts").isFile) {
        "implementation"(project(":presentation:${project.name}"))
    }
    "implementation"(libraries.findLibrary("androidx-compose-material-icons-core").get())
    "implementation"(libraries.findLibrary("androidx-compose-ui-tooling-preview").get())
    "debugImplementation"(libraries.findLibrary("androidx-compose-ui-tooling").get())
}
