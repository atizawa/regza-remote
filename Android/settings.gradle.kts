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
// 画面の状態と操作の型 (共有の Swift のプレゼンテーションのモジュールと 1 対 1)
rootDir.resolve("presentation").listFiles { file -> file.resolve("build.gradle.kts").isFile }.orEmpty().sortedBy { it.name }
    .forEach { include(":presentation:${it.name}") }

// OS の機能とつなぐ部分 (アプリの組み立て・Live Updates・画面のない入口・ウィジェット。iOS の AppServices・LiveActivity・SystemActions・Widgets)
rootDir.resolve("platform").listFiles { file -> file.resolve("build.gradle.kts").isFile }.orEmpty().sortedBy { it.name }
    .forEach { include(":platform:${it.name}") }

rootDir.resolve("ui").listFiles { file -> file.resolve("build.gradle.kts").isFile }.orEmpty().sortedBy { it.name }
    .forEach { include(":ui:${it.name}") }
