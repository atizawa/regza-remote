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
    ":swiftkit-core",
    ":behavior-tests",
)

// 画面のモジュール (共通の部品 ui:common と、機能ごとの ui:<機能>) は、ui/ の下のフォルダから読む
// (機能を足すときは、フォルダを作るだけでよい)
rootDir.resolve("ui").listFiles { file -> file.resolve("build.gradle.kts").isFile }.orEmpty().sortedBy { it.name }
    .forEach { include(":ui:${it.name}") }
