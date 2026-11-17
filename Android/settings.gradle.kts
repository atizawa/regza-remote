pluginManagement {
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
include(":app", ":core:bridge", ":core:design", ":core:localization", ":core:ui", ":swiftkit-core", ":behavior-tests")
