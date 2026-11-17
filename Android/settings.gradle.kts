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
include(
    ":app",
    ":core:bridge",
    ":core:design",
    ":core:localization",
    ":core:ui",
    ":feature:remote",
    ":feature:player",
    ":feature:guide",
    ":feature:program",
    ":feature:channels",
    ":feature:reservations",
    ":feature:settings",
    ":swiftkit-core",
    ":behavior-tests",
)
