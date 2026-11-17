// Compose を使う Android のライブラリ (色・文言・共通の部品・機能の画面) の共通の決まり
import com.android.build.api.dsl.LibraryExtension

plugins {
    id("regza.android.library")
    id("org.jetbrains.kotlin.plugin.compose")
}

val libraries = extensions.getByType<VersionCatalogsExtension>().named("libs")

extensions.configure<LibraryExtension> {
    buildFeatures {
        compose = true
    }
}

dependencies {
    "implementation"(platform(libraries.findLibrary("androidx-compose-bom").get()))
}
