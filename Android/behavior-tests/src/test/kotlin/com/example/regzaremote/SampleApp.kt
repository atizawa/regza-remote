package com.example.regzaremote

import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidStorage
import java.util.Optional
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout

/** メモリに置くだけの保存先 (アプリの AndroidStorage の代わり) */
class MemoryStorage : RegzaAndroidStorage {
    val values = mutableMapOf<String, String>()
    override fun value(key: String): Optional<String> = Optional.ofNullable(values[key])
    override fun setValue(value: String, key: String) {
        values[key] = value
    }
}

/**
 * 見本の返事で組み立てたアプリ。アプリと同じく send で操作を送り、xxxStates で state を受け取る。
 * 確かめ方は Shopify の Reflex と同じく、操作を送って、state が期待どおりになるまで待つ
 */
class SampleApp {
    val storage = MemoryStorage()
    val app: RegzaAndroidApp = RegzaAndroidApp.sample(storage)
    val send: Send = AppSend(app)

    /** state が条件を満たすまで待って返す (5 秒で失敗にする)。開いていない (null) あいだは待つ */
    fun <T> until(states: Flow<T?>, condition: (T) -> Boolean = { true }): T = runBlocking {
        withTimeout(5.seconds) { states.filterNotNull().first(condition) }
    }

    /** 開いていない (null) ことを確かめる */
    fun <T> closed(states: Flow<T?>): Boolean = runBlocking {
        withTimeout(5.seconds) { states.first { it == null } } == null
    }
}
