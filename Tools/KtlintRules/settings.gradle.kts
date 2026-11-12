pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories { mavenCentral() }
    versionCatalogs {
        create("libs") { from(files("../../Android/gradle/libs.versions.toml")) }
    }
}

rootProject.name = "regza-ktlint-rules"
