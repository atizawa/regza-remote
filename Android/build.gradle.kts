plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}

// Swift の .so と、swift-java が作る Java のクラスを作る (mise run build-swift)。
// app と swiftkit-core (swift-java のソースを使う) のビルドの前に動く。Swift のソースや設定が変わったときだけ動く
tasks.register<Exec>("buildSwift") {
    description = "mise run build-swift で、Swift の .so と swift-java の Java のクラスを作る"
    workingDir = rootDir
    // Android Studio から動かすと PATH に mise がないことがあるので、よく入っている場所から探す
    val mise = listOf("/opt/homebrew/bin/mise", "/usr/local/bin/mise", "${System.getProperty("user.home")}/.local/bin/mise")
        .firstOrNull { File(it).canExecute() } ?: "mise"
    commandLine(mise, "run", "build-swift")

    inputs.files(fileTree("../Packages/RegzaCore") { include("Package.swift", "Sources/**") })
    inputs.files(fileTree("RegzaAndroid") { exclude("Sources/RegzaCoreJava/Generated/**") })
    inputs.file("mise.toml")
    outputs.dir("app/src/main/jniLibs")
    outputs.dir(".build/swift/regzacore-java")
    outputs.dir(".build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java")
    outputs.dir(".build/swift/checkouts/swift-java/SwiftKitCore/src/main")
}
