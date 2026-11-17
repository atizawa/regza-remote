package com.example.regzaremote.appservices.preview

import com.example.regzaremote.bridge.HostSwiftRuntime
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaFakeApp
import com.example.regzaremote.uicommon.BuildConfig
import java.io.File
import java.nio.file.Files
import java.util.concurrent.ConcurrentHashMap
import org.swift.swiftkit.core.SwiftLibraries

/**
 * 偽物のテレビ・録画サーバーで組み立てる (debug だけ)。プレビューの準備 (PreviewAppFactory) が名前で探して呼ぶ。
 * release の APK にはないので、プレビューの準備は本番のコードから偽物を参照しない
 */
object FakeApps {
    @JvmStatic
    fun make(inEditor: Boolean): RegzaAndroidApp {
        if (inEditor) HostSwiftRuntime.loadLibraries { HostSwiftLibraries.load() }
        return RegzaFakeApp.make("").get()
    }
}

/**
 * エディタの横のプレビューで、ホスト向けにビルドした Swift のライブラリを読み込む。
 *
 * swift-java の Java のクラスは、使われるときにライブラリを名前で探す (java.library.path か、jar の中)。
 * Android Studio のプレビューではどちらにもないので、先に場所を指定して読み込み、swift-java には読み込み済みとして登録する。
 * Android Studio はコードを直すとプレビューのクラスを読み込み直し、同じファイルのライブラリは別の読み込みから使えないので、
 * 読み込むたびに一時フォルダへ写してから読み込む
 */
private object HostSwiftLibraries {
    fun load() {
        check(BuildConfig.HOST_SWIFT_LIBRARIES.isNotEmpty()) { "エディタの横のプレビューは debug のビルドでだけ使えます" }
        val built = File(BuildConfig.HOST_SWIFT_LIBRARIES)
        check(built.isDirectory) { "$built がありません。mise run prepare-android-preview で作ってください" }
        // 接続ライブラリを同じ一時フォルダに置き、依存先を相対パスで解決できるようにする。
        val copied = Files.createTempDirectory("regza-preview").toFile().apply { deleteOnExit() }
        // Swift のランタイムはコピーせず、接続ライブラリの依存先として OS に解決させる。
        val names = listOf(SwiftLibraries.LIB_NAME_SWIFT_JAVA, "RegzaAndroid")

        @Suppress("UNCHECKED_CAST")
        val loaded = SwiftLibraries::class.java.getDeclaredField("loadedLibraries")
            .apply { isAccessible = true }.get(null) as ConcurrentHashMap<String, File>
        for (name in names) {
            val file = System.mapLibraryName(name)
            val copy = File(copied, file).apply { deleteOnExit() }
            File(built, file).canonicalFile.copyTo(copy)
            System.load(copy.path)
            loaded[name] = copy
        }
    }
}
