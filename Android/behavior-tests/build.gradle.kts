import groovy.json.JsonSlurper
import java.nio.file.Files
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// 振る舞いのテスト (../../BehaviorTests。Shopify の Reflex と同じ作り) の Android 側の相手 (regza-android)。
// iOS 側の相手 (regza) と同じ約束事 (1 行ずつの命令と JSON) を話し、操作を送るところと state を受け取るところだけを、
// アプリと同じ道 (Kotlin の Send と xxxStates → swift-java のつなぎ → 窓口 → 共有の ViewModel) で行う。
// エミュレーターではなくホストの JVM で動かし、窓口とつなぎはホスト向けの共有ライブラリを読み込む。
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

// 窓口とつなぎをホスト向けにビルドし、Java が読み込む名前 (RegzaAndroid・SwiftJava) で置く。
// System.mapLibraryName は macOS なら .dylib、Linux なら .so を返す。
val jvmHostLibs = androidDir.resolve(".build/jvm-host/libs")
val isMacOS = System.getProperty("os.name").startsWith("Mac")
val isLinux = System.getProperty("os.name").startsWith("Linux")
val hostLibraries = mapOf(
    System.mapLibraryName("RegzaAndroid") to System.mapLibraryName("RegzaJVMHost"),
    System.mapLibraryName("SwiftJava") to System.mapLibraryName("SwiftJava"),
)
val buildJvmHost = tasks.register<Exec>("buildJvmHost") {
    description = "窓口とつなぎを、ホストの JVM から読み込む共有ライブラリにする"
    dependsOn(":app:buildSwift")
    workingDir = androidDir
    // Android 向け (app の buildSwift) と同じく、mise で固定した Swift を PATH の並びにかかわらず使う (scripts/swift-toolchain.sh)
    val mise = rootProject.extra["mise"] as String
    commandLine(mise, "run", "build-jvm-host")
    environment("MISE_EXECUTABLE", mise)
    // ホスト向けライブラリに入る Swift や、依存の版・設定が変わったときだけ動く。
    // RegzaAndroid は、ホスト向けには入らない Android だけの部品 (Looper・BoringSSL) を外し、それ以外をすべて見る
    // (つなぎのフォルダが増えても、ここを直さずに見るように)。依存の版は RegzaAndroid/Package.resolved にだけ書かれる
    inputs.files(fileTree(androidDir.resolve("../Packages/RegzaCore")) { include("Package.swift", "Sources/**", "Plugins/**", "Tools/**") })
    inputs.files(fileTree(androidDir.resolve("../OpenAPI")) { include("regza-tv.yaml", "mirakurun.json", "epgstation.json") })
    inputs.files(
        fileTree(androidDir.resolve("RegzaAndroid")) {
            include("Package.swift", "Package.resolved", "Sources/**")
            exclude("Sources/RegzaAndroid/**", "Sources/CBoringSSL/**", "Sources/CAndroidMainLoop/**")
        },
    )
    inputs.files(fileTree(androidDir.resolve("RegzaAndroidBridge")) { include("Package.swift", "Sources/**") })
    inputs.file(androidDir.resolve("mise.toml"))
    inputs.file(androidDir.resolve("../toolchains.toml"))
    inputs.property("hostOS", System.getProperty("os.name"))
    inputs.property("hostArch", System.getProperty("os.arch"))
    inputs.dir(androidDir.resolve("scripts"))
    // ホストのライブラリは JDK の JNI と、macOS では SDK にもよるので、上げたら作り直す。
    // SDK の版は xcrun で調べる (xcodebuild より速い)。調べられなくても (Command Line Tools だけのときなど) ビルドは止めない
    inputs.file(androidDir.resolve("gradle/gradle-daemon-jvm.properties"))
    if (isMacOS) {
        inputs.property(
            "macOSSDK",
            providers.exec {
                commandLine("xcrun", "--sdk", "macosx", "--show-sdk-build-version")
                isIgnoreExitValue = true
            }.standardOutput.asText,
        )
    }
    outputs.dir(jvmHostLibs)
    doLast {
        // Gradle が outputs.files の親として debug/ を先に作ると、SwiftPM の互換リンクを妨げる。
        // 実際の出力先を SwiftPM に問い合わせ、公開する libs/ だけを Gradle の成果物にする。
        val products = File(
            providers.exec {
                workingDir(androidDir)
                commandLine(
                    mise, "exec", "--", "swift", "build", "--package-path", "RegzaAndroid",
                    "--scratch-path", ".build/jvm-host", "--product", "RegzaJVMHost", "--show-bin-path",
                )
            }.standardOutput.asText.get().trim(),
        )
        jvmHostLibs.mkdirs()
        val libraries = hostLibraries.mapValues { (_, built) -> products.resolve(built) }.toMutableMap()
        if (isLinux) {
            // mise の Swift は /usr/lib/swift に入るとは限らない。Java が swiftCore を名前で読めるようにする。
            val targetInfo = JsonSlurper().parseText(
                providers.exec {
                    workingDir(androidDir)
                    commandLine(mise, "exec", "--", "swift", "-print-target-info")
                }.standardOutput.asText.get(),
            ) as Map<*, *>
            val runtimePaths = (targetInfo["paths"] as Map<*, *>)["runtimeLibraryPaths"] as List<*>
            val swiftCore = System.mapLibraryName("swiftCore")
            libraries[swiftCore] = checkNotNull(
                runtimePaths.map { File(it.toString(), swiftCore) }.firstOrNull { it.isFile },
            ) { "Swift のランタイムが見つかりません: $runtimePaths" }
        }
        libraries.forEach { (name, built) ->
            check(built.isFile) { "ホスト向けライブラリがありません: $built" }
            val link = jvmHostLibs.resolve(name).toPath()
            Files.deleteIfExists(link)
            Files.createSymbolicLink(link, built.toPath())
        }
    }
}

// installDist で作る起動の台本にも、ホスト向けライブラリの場所を渡す。
application.applicationDefaultJvmArgs = listOf(
    "-Djava.library.path=$jvmHostLibs",
    "--enable-native-access=ALL-UNNAMED",
    // JSON の出力は UTF-8。Linux の C ロケールでも、日本語を '?' に置き換えない。
    "-Dstdout.encoding=UTF-8",
    "-Dstderr.encoding=UTF-8",
)
tasks.named("installDist") { dependsOn(buildJvmHost) }
