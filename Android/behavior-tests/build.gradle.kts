import java.nio.file.Files
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// 振る舞いのテスト (Shopify の Reflex と同じく、画面を描かずに ViewModel の state と操作を確かめる)。
// エミュレーターではなく Mac の JVM で動かす。アプリと同じ道 (Kotlin の Send と xxxStates → swift-java のつなぎ → 窓口 →
// 共有の ViewModel) を通るよう、窓口とつなぎを macOS 向けにビルドした .dylib を読み込む。
// 外からの入力は見本の返事 (RegzaAndroidApp.sample の SampleTransport) で渡すので、テレビにも録画サーバーにもつながない
plugins {
    alias(libs.plugins.kotlin.jvm)
}

val androidDir = rootDir

sourceSets.main {
    // アプリと同じ、swift-java が作った Java のクラスと、ツールが作った Kotlin の部品 (Send・xxxStates)
    java.srcDirs(
        "../.build/swift/regzashared-java",
        "../.build/swift/regzapresentation-java",
        "../.build/swift/regzabridge-java",
    )
    kotlin.srcDir("../.build/swift/screen-glue-kotlin")
}

dependencies {
    implementation(project(":swiftkit-core"))
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.kotlin.test.junit)
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

// 作られるソースは app の buildSwift (mise run build-swift) が作る
tasks.named("compileJava") { dependsOn(":app:buildSwift") }
tasks.named("compileKotlin") { dependsOn(":app:buildSwift") }

// 窓口とつなぎを macOS 向けにビルドし、Java が読み込む名前 (RegzaAndroid・SwiftJava) で置く
val jvmHostLibs = androidDir.resolve(".build/jvm-host/libs")
val buildJvmHost = tasks.register<Exec>("buildJvmHost") {
    description = "窓口とつなぎを、Mac の JVM から読み込む .dylib にする"
    dependsOn(":app:buildSwift")
    workingDir = androidDir
    val mise = listOf("/opt/homebrew/bin/mise", "/usr/local/bin/mise", "${System.getProperty("user.home")}/.local/bin/mise")
        .firstOrNull { File(it).canExecute() } ?: "mise"
    commandLine(
        mise, "exec", "--", "swift", "build", "--package-path", "RegzaAndroid", "--scratch-path", ".build/jvm-host",
        "--product", "RegzaJVMHost",
    )
    doLast {
        val products = androidDir.resolve(".build/jvm-host/debug")
        jvmHostLibs.mkdirs()
        mapOf("libRegzaAndroid.dylib" to "libRegzaJVMHost.dylib", "libSwiftJava.dylib" to "libSwiftJava.dylib").forEach { (name, built) ->
            val link = jvmHostLibs.resolve(name).toPath()
            Files.deleteIfExists(link)
            Files.createSymbolicLink(link, products.resolve(built).toPath())
        }
    }
}

tasks.test {
    dependsOn(buildJvmHost)
    // Swift の標準ライブラリは macOS に入っているものを使う
    systemProperty("java.library.path", "$jvmHostLibs:/usr/lib/swift")
    jvmArgs("--enable-native-access=ALL-UNNAMED")
    testLogging { events("passed", "failed") }
}
