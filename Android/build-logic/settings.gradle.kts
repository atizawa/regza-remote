// Android のモジュールが共通に使うビルドの決まり (convention plugin)。ルートの settings.gradle.kts が includeBuild で読み込む
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
    versionCatalogs {
        create("libs") { from(files("../gradle/libs.versions.toml")) }
    }
}

rootProject.name = "build-logic"
