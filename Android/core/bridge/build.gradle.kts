// Swift の窓口とつなぎ。アプリと共有の Swift (Packages/RegzaCore) を Android から使うための部品をまとめる:
// - Swift の .so (mise run build-swift が作る。共通のものは main、本番の libRegzaAndroid.so は release、
//   偽物の入口とテスト専用の .so を足したものは debug の jniLibs)
// - swift-java が作る窓口の Java のクラス (com.example.regzaremote.core の RegzaAndroidApp など)・すべての送り先をまとめた Send と
//   state の Flow (screen-glue が作る bridge)
// 画面の状態と操作の型は presentation/<名前> に分けて置き、このモジュールはそのすべてに依存する。
// 機能の画面のモジュールはこのモジュールを読み込まず、自分の機能の presentation だけを使う。
// 画面やアプリの組み立ては app に置き、このモジュールは画面を知らない
plugins {
    id("regza.android.library")
}

android {
    namespace = "com.example.regzaremote.bridge"
    // NDK の版 (libs.versions.toml)。Swift の .so のビルド (buildSwift) に渡し、Android SDK の ndk/<版> になければ build-swift が入れる
    ndkVersion = libs.versions.ndk.get()

    defaultConfig {
        // swift-java が作ったクラスと SwiftKitCore を、アプリの縮小で消さない決まり
        consumerProguardFiles("consumer-rules.pro")
    }

    // swift-java が RegzaAndroid の Swift から作った Java のクラス (buildSwift で作られる)
    sourceSets.getByName("main").java.srcDirs(
        "../../.build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java",
        // 窓口 (RegzaAndroidApp と、その状態・操作の型) の Java のクラス
        "../../.build/swift/regzabridge-java",
    )
    // 偽物のテレビ・録画サーバーで組み立てる入口 (RegzaFakeApp) の Java のクラス。debug だけに入れる (本番の .so にもない)
    sourceSets.getByName("debug").java.srcDirs("../../.build/swift/regzafakes-java")
    // 画面が受け取る送り先 (Send) と、Swift の窓口に送る AppSend (Android/ScreenGlue の screen-glue が作る)
    sourceSets.getByName("main").kotlin.srcDirs("../../.build/swift/screen-glue-kotlin/bridge")
}

// Swift の .so と、swift-java が作る Java のクラスを作る (mise run build-swift)。
// core:bridge と swiftkit-core (swift-java のソースを使う) のビルドの前に動く。Swift のソースや設定が変わったときだけ動く
val buildSwift = tasks.register<Exec>("buildSwift") {
    description = "mise run build-swift で、Swift の .so と swift-java の Java のクラスを作る"
    val androidDir = rootDir
    workingDir = androidDir
    // mise の場所はルートの build.gradle.kts で探す。mise の環境に既に別の Swift があると PATH の順番を直さない場合があるため、
    // build-swift が `mise which swift` の実体を直接選べるよう、mise 自身の場所も渡す
    val mise = rootProject.extra["mise"] as String
    commandLine(mise, "run", "build-swift")
    environment("MISE_EXECUTABLE", mise)
    // Gradle と同じ SDK の場所と ndkVersion を渡す。Android Gradle Plugin は場所を聞くだけでは NDK を入れないので、
    // なければ build-swift が入れる
    val sdk = androidComponents.sdkComponents.sdkDirectory
    environment("NDK_VERSION", android.ndkVersion)
    // ICU はデータを日本語・英語に絞って作り直す。比べるときは -PregzaFullICU=true で元のまま入れる。
    // 環境変数ではなくプロパティで受け取り、作り直しの判断にも含める (常駐の Gradle に環境変数が届かず、切り替えても飛ばされないように)
    val fullICU = providers.gradleProperty("regzaFullICU").map { it.toBoolean() }.getOrElse(false)
    environment("REGZA_FULL_ICU", if (fullICU) "1" else "0")
    inputs.property("regzaFullICU", fullICU)
    doFirst { environment("ANDROID_HOME", sdk.get().asFile.path) }

    inputs.files(fileTree(androidDir.resolve("../Packages/RegzaCore")) { include("Package.swift", "Sources/**", "Plugins/**", "Tools/**") })
    inputs.files(fileTree(androidDir.resolve("../OpenAPI")) { include("regza-tv.yaml", "mirakurun.json", "epgstation.json") })
    inputs.files(
        fileTree(androidDir.resolve("RegzaAndroid")) {
            exclude(
                "Sources/RegzaSharedJava/Generated/**",
                "Sources/RegzaPresentationJava/Generated/**",
                "Sources/RegzaAndroidBridgeJava/Generated/**",
                "Sources/RegzaAndroidFakesJava/Generated/**",
                // build-swift が共通の設定から書き出すもの
                "Sources/RegzaAndroid/swift-java.config",
            )
        },
    )
    inputs.files(fileTree(androidDir.resolve("RegzaAndroidBridge")) { include("Package.swift", "Sources/**") })
    inputs.file(androidDir.resolve("mise.toml"))
    inputs.file(androidDir.resolve("../toolchains.toml"))
    inputs.dir(androidDir.resolve("scripts"))
    // 窓口のつなぎを作る道具
    inputs.files(fileTree(androidDir.resolve("ScreenGlue")) { include("Package.swift", "Package.resolved", "Sources/**") })
    inputs.property("ndkVersion", android.ndkVersion)
    outputs.dir("src/main/jniLibs")
    // 本番の libRegzaAndroid.so と、偽物の入口とテスト専用の .so を足した debug のもの
    outputs.dir("src/release/jniLibs")
    outputs.dir("src/debug/jniLibs")
    outputs.dir(androidDir.resolve(".build/swift/regzashared-java"))
    outputs.dir(androidDir.resolve(".build/swift/regzapresentation-java"))
    outputs.dir(androidDir.resolve(".build/swift/presentation-java"))
    outputs.file(androidDir.resolve(".build/swift/presentation-types.txt"))
    outputs.dir(androidDir.resolve(".build/swift/regzabridge-java"))
    outputs.dir(androidDir.resolve(".build/swift/regzafakes-java"))
    outputs.dir(androidDir.resolve(".build/swift/screen-glue-kotlin"))
    outputs.dir(
        androidDir.resolve(".build/swift/plugins/outputs/regzaandroid/RegzaAndroid/destination/JExtractSwiftPlugin/src/generated/java"),
    )
    outputs.dir(androidDir.resolve(".build/swift/checkouts/swift-java/SwiftKitCore/src/main"))
    // swift-java が作る Swift のつなぎ (Git に入れていない)。消えたら作り直す (behavior-tests の buildJvmHost もこれを使う)
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaSharedJava/Generated"))
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaPresentationJava/Generated"))
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated"))
    outputs.dir(androidDir.resolve("RegzaAndroid/Sources/RegzaAndroidFakesJava/Generated"))
    outputs.file(androidDir.resolve("RegzaAndroid/Sources/RegzaAndroid/swift-java.config"))
}
tasks.named("preBuild") { dependsOn(buildSwift) }

dependencies {
    // 画面の状態と操作の型と、モジュールごとの送り先。窓口の関数が使うので、使う側 (アプリの組み立て) にも見せる
    rootProject.subprojects.filter { it.path.startsWith(":presentation:") }.forEach { api(project(it.path)) }
    // swift-java が作ったクラスが使う Java 側。つなぎの型の一部なので、使う側にも見せる
    api(project(":swiftkit-core"))
    // 画面の state の Flow (screen-glue が作る) が使う
    api(libs.kotlinx.coroutines.android)
}
