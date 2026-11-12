package com.example.regzaremote.appservices.preview

import com.example.regzaremote.BuildConfig
import com.example.regzaremote.bridge.AppSend
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidStorage
import java.io.File
import java.nio.file.Files
import java.util.Optional
import java.util.concurrent.ConcurrentHashMap
import org.swift.swiftkit.core.SwiftLibraries

/** プレビュー用の通信・保存先・Swift 実行環境を準備する。 */
object PreviewAppFactory {
    fun makeApp(inEditor: Boolean, setUp: (Send) -> Unit): Pair<RegzaAndroidApp, Send> {
        if (inEditor) MacSwiftLibraries.load()
        val app = RegzaAndroidApp.sample(PreviewStorage(), "").get()
        val send = AppSend(app)
        setUp(send)
        if (inEditor) app.contractWaitUntilIdle().get()
        return app to send
    }
}

/** メモリに置くだけの保存先 (プレビューで、アプリの接続情報を書き換えないように) */
private class PreviewStorage : RegzaAndroidStorage {
    private val values = mutableMapOf<String, String>()
    override fun value(key: String): Optional<String> = Optional.ofNullable(values[key])
    override fun setValue(value: String, key: String) {
        values[key] = value
    }
}

/**
 * エディタの横のプレビューで、Mac 向けにビルドした Swift のライブラリを読み込む。
 *
 * swift-java の Java のクラスは、使われるときにライブラリを名前で探す (java.library.path か、jar の中)。
 * Android Studio のプレビューではどちらにもないので、先に場所を指定して読み込み、swift-java には読み込み済みとして登録する。
 * Android Studio はコードを直すとプレビューのクラスを読み込み直し、同じファイルのライブラリは別の読み込みから使えないので、
 * 読み込むたびに一時フォルダへ写してから読み込む
 */
private object MacSwiftLibraries {
    fun load() {
        check(BuildConfig.MAC_SWIFT_LIBRARIES.isNotEmpty()) { "エディタの横のプレビューは debug のビルドでだけ使えます" }
        val built = File(BuildConfig.MAC_SWIFT_LIBRARIES)
        check(built.isDirectory) { "$built がありません。./gradlew :behavior-tests:buildJvmHost で作ってください" }
        // libRegzaAndroid は同じフォルダの libSwiftJava を使う (@loader_path) ので、両方を同じ一時フォルダに写す
        val copied = Files.createTempDirectory("regza-preview").toFile().apply { deleteOnExit() }
        val names = mapOf(SwiftLibraries.LIB_NAME_SWIFT_JAVA to "libSwiftJava.dylib", "RegzaAndroid" to "libRegzaAndroid.dylib")

        @Suppress("UNCHECKED_CAST")
        val loaded = SwiftLibraries::class.java.getDeclaredField("loadedLibraries")
            .apply { isAccessible = true }.get(null) as ConcurrentHashMap<String, File>
        for ((name, file) in names) {
            val copy = File(copied, file).apply { deleteOnExit() }
            File(built, file).canonicalFile.copyTo(copy)
            System.load(copy.path)
            loaded[name] = copy
        }
    }
}
