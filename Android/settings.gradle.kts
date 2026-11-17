pluginManagement {
    // Android のモジュールが共通に使うビルドの決まり (regza.android.*)
    includeBuild("build-logic")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "RegzaRemote"
include(
    ":app",
    ":core:bridge",
    ":core:design",
    ":core:localization",
    ":core:ui",
    ":swiftkit-core",
    ":behavior-tests",
)

// 機能の画面のモジュールは、feature/ の下のフォルダから読む (機能を足すときは、フォルダを作るだけでよい)
rootDir.resolve("feature").listFiles { file -> file.resolve("build.gradle.kts").isFile }.orEmpty().sortedBy { it.name }
    .forEach { include(":feature:${it.name}") }
