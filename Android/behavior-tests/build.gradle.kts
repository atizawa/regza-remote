import java.nio.file.Files
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// 振る舞いのテスト (../../BehaviorTests。Shopify の Reflex と同じ作り) の Android 側の相手 (regza-android)。
// iOS 側の相手 (regza) と同じ約束事 (1 行ずつの命令と JSON) を話し、操作を送るところと state を受け取るところだけを、
// アプリと同じ道 (Kotlin の Send と xxxStates → swift-java のつなぎ → 窓口 → 共有の ViewModel) で行う。
// エミュレーターではなく Mac の JVM で動かし、窓口とつなぎは macOS 向けにビルドした .dylib を読み込む。
// 見本の返事 (RegzaAndroidApp.sample の SampleTransport) で組み立てるので、テレビにも録画サーバーにもつながない
plugins {
    alias(libs.plugins.kotlin.jvm)
    // 振る舞いのテスト (BehaviorTests) の Android 側の相手 (ContractDriver) を、起動できる形にする
    application
}

application {
    mainClass.set("com.example.regzaremote.ContractDriverKt")
    applicationName = "regza-android"
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

// installDist で作る起動の台本にも、.dylib の場所を渡す
application.applicationDefaultJvmArgs = listOf("-Djava.library.path=$jvmHostLibs:/usr/lib/swift", "--enable-native-access=ALL-UNNAMED")
tasks.named("installDist") { dependsOn(buildJvmHost) }
