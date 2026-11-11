package com.example.regzaremote

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.regzaremote.bridge.AppSend
import com.example.regzaremote.bridge.appStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppState
import com.example.regzaremote.core.AppTab
import com.example.regzaremote.core.RegzaAndroid
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidStorage
import java.net.InetAddress
import java.net.ServerSocket
import java.util.Optional
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.take
import kotlinx.coroutines.future.await
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Mac の JVM では通らない Android の境界 (.so・JNI・Looper・Bionic・BoringSSL) のスモークテスト。 */
@RunWith(AndroidJUnit4::class)
class AndroidRuntimeSmokeTest {
    /**
     * Application.onCreate で Swift の .so と MainActor の Looper 連携を初期化し、JNI 越しに state を受け取る。
     * Flow の待機を繰り返し取り消したあと、Swift Task と JNI の参照につながる待機が残らないことも確かめる。
     */
    @Test
    fun swiftLibrariesJniLooperAndFlowCancellation() = runBlocking {
        val application = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext
        assertTrue(application is RegzaApplication)

        val app = RegzaAndroidApp.sample(MemoryStorage(), "").orElse(null)
        assertNotNull(app)
        app ?: return@runBlocking

        // Observation の変更通知が Swift MainActor → JNI → Kotlin Flow まで届くことを確かめる。
        val states = Channel<AppState>(Channel.UNLIMITED)
        val collector = launch(Dispatchers.Default) {
            app.appStates().filterNotNull().take(2).collect(states::send)
        }
        withTimeout(TIMEOUT) { states.receive() }
        waitForPendingStateWaits(app, 1)
        AppSend(app)(AppAction.selectTab(AppTab.guide()))
        val changed = withTimeout(TIMEOUT) { states.receive() }
        assertEquals(AppTab.guide().rawValue, changed.tab.rawValue)
        withTimeout(TIMEOUT) { collector.join() }
        waitForPendingStateWaits(app, 0)

        // nextState の待機中に Flow を止める競合を複数回通す。
        repeat(10) {
            val waiting = launch(Dispatchers.Default) { app.appStates().drop(1).first() }
            waitForPendingStateWaits(app, 1)
            waiting.cancelAndJoin()
            waitForPendingStateWaits(app, 0)
        }
    }

    /** Swift の SocketTransport が Android/Bionic のソケットで端末内のサーバーと送受信できる。 */
    @Test
    fun bionicSocketConnectsFromSwift() = runBlocking {
        ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { server ->
            val finished = CountDownLatch(1)
            val failure = AtomicReference<Throwable?>()
            val responder = thread(name = "runtime-smoke-http", isDaemon = true) {
                try {
                    server.accept().use { socket ->
                        socket.soTimeout = TIMEOUT.toInt()
                        val input = socket.getInputStream().bufferedReader()
                        while (input.readLine()?.isNotEmpty() == true) {
                            // 空行まで HTTP のリクエストヘッダーを読む
                        }
                        socket.getOutputStream().apply {
                            write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok".toByteArray())
                            flush()
                        }
                    }
                } catch (error: Throwable) {
                    failure.set(error)
                } finally {
                    finished.countDown()
                }
            }

            val result = withTimeout(TIMEOUT) {
                RegzaAndroid.regzaAndroidNetworkProbe("http://127.0.0.1:${server.localPort}/smoke").await()
            }
            assertEquals("200\nok", result)
            assertTrue(finished.await(TIMEOUT, TimeUnit.MILLISECONDS))
            responder.join(1_000)
            assertNull(failure.get())
        }
    }

    /** APK に入れた BoringSSL が使え、Android のシステム CA を見つけられる。 */
    @Test
    fun boringSSLReadsAndroidTrustStore() {
        assertTrue(RegzaAndroid.regzaAndroidTLSIsReady())
    }

    private suspend fun waitForPendingStateWaits(app: RegzaAndroidApp, expected: Long) {
        withTimeout(TIMEOUT) {
            while (app.pendingStateWaitCount().await() != expected) delay(10)
        }
    }

    /** テレビや録画サーバーへ接続しない見本の Swift ViewModel に渡す保存先。 */
    private class MemoryStorage : RegzaAndroidStorage {
        private val values = mutableMapOf<String, String>()

        override fun value(key: String): Optional<String> = Optional.ofNullable(values[key])

        override fun setValue(value: String, key: String) {
            values[key] = value
        }
    }

    private companion object {
        const val TIMEOUT = 10_000L
    }
}
