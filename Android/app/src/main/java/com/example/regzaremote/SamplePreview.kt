package com.example.regzaremote

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidStorage
import java.io.File
import java.nio.file.Files
import java.util.Optional
import java.util.concurrent.ConcurrentHashMap
import org.swift.swiftkit.core.SwiftLibraries

/**
 * 画面のプレビューの準備。プレビューそのものは、それぞれの画面のファイルの末尾に置く。iOS の開発用の見本・振る舞いのテストと同じ見本の返事 (RegzaSample の SampleTransport) で、
 * 共有の ViewModel を組み立てて、本物の state を画面に渡す (テレビにも録画サーバーにもつながない)。
 *
 * state は Swift の値なので、Swift のライブラリがないと作れない。
 * - 「Run Preview」(エミュレーター): アプリと同じ Android 向けの .so を使う
 * - エディタの横のプレビュー (Android Studio が Mac の JVM で描く): 振る舞いのテストと同じ Mac 向けのライブラリ
 *   (behavior-tests の buildJvmHost が作る) を読み込む (MacSwiftLibraries)。読み込めなければ、その理由を出す
 *
 * Swift の型 (AppRoute や Action など) は、ライブラリを読み込んだあとでないと作れないので、setUp と content の中で作る
 *
 * @param setUp 組み立てたあとに送る操作 (一覧を読み込むなど)
 */
@Composable
fun SamplePreview(setUp: (Send) -> Unit = {}, content: @Composable (RegzaAndroidApp, Send) -> Unit) {
    MaterialTheme(colorScheme = AppTheme.colorScheme) {
        Surface(modifier = Modifier.fillMaxSize(), color = AppTheme.background) {
            val inEditor = LocalInspectionMode.current
            val sample = remember {
                runCatching {
                    if (inEditor) MacSwiftLibraries.load()
                    val app = RegzaAndroidApp.sample(PreviewStorage(), "").get()
                    val send = AppSend(app)
                    setUp(send)
                    // エディタの横のプレビューは、描き直しを待たずに 1 回だけ描くので、送った操作が終わってから描く
                    if (inEditor) app.contractWaitUntilIdle().get()
                    app to send
                }
            }
            sample.fold(
                onSuccess = { (app, send) -> content(app, send) },
                onFailure = { error ->
                    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                        Text("Swift のライブラリを読み込めませんでした。「Run Preview」でエミュレーターに出してください。\n\n$error")
                    }
                },
            )
        }
    }
}

/** 見本のチャンネル (SampleTransport のチャンネル一覧の 1 局目) */
const val SAMPLE_CHANNEL = "JP-G00000001"

/** 見本の番組 (SampleTransport の番組表の、1 局目の番組) */
const val SAMPLE_PROGRAM = 1001L

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
