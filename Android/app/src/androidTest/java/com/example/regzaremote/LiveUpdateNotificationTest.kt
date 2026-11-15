package com.example.regzaremote

import android.app.Notification
import android.os.Build
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.regzaremote.core.Date
import com.example.regzaremote.core.LiveStatus
import com.example.regzaremote.core.NowPlayingKind
import com.example.regzaremote.liveupdate.LiveUpdateNotification
import java.util.Optional
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** 共有の LiveStatus から組み立てた通知の中身 (iOS の Live Activity と同じものを出すこと) */
@RunWith(AndroidJUnit4::class)
class LiveUpdateNotificationTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val nowSeconds = 1_800_000_000.0
    private val nowMillis = (nowSeconds * 1000).toLong()

    private fun status(
        kind: NowPlayingKind = NowPlayingKind.broadcast(),
        title: String = "番組A",
        isAdvancing: Boolean = true,
        isConnected: Boolean = true,
        nextStart: Double? = null,
    ): LiveStatus = LiveStatus.`init`(
        kind, "テスト局", "テスト", title, "第1話", "ドラマ", 600, 1800, isAdvancing, Date.`init`(nowSeconds),
        Optional.ofNullable(nextStart?.let { Date.`init`(it) }), if (nextStart == null) 0 else 3600, if (nextStart == null) "" else "番組B",
        false, Optional.empty(), isConnected,
    )

    private fun Notification.title() = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
    private fun Notification.text() = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
    private fun Notification.actionTitles() = actions.orEmpty().map { it.title.toString() }

    @Test
    fun broadcastShowsProgramAndCountsDownToItsEnd() {
        val notification = LiveUpdateNotification.build(context, status(), nowMillis)

        assertEquals("番組A", notification.title())
        assertEquals("第1話", notification.text())
        assertEquals("テスト局", notification.extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString())
        // 通知のボタンは 3 つまでなので、放送は音量を消音にまとめる
        assertEquals(listOf("チャンネル−", "チャンネル＋", "消音"), notification.actionTitles())
        assertTrue("消さずに出し続ける", notification.flags and Notification.FLAG_ONGOING_EVENT != 0)
        // 残り時間はシステムが進める時計で出す
        assertEquals(nowMillis + 1200 * 1000, notification.`when`)
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertTrue(notification.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
        if (Build.VERSION.SDK_INT >= 36) {
            assertTrue("Live Updates に昇格を頼む", notification.extras.getBoolean(Notification.EXTRA_REQUEST_PROMOTED_ONGOING))
            assertEquals("テスト", notification.shortCriticalText)
            assertEquals(Notification.ProgressStyle::class.java.name, notification.extras.getString(Notification.EXTRA_TEMPLATE))
            assertEquals(333, notification.extras.getInt(Notification.EXTRA_PROGRESS))
        } else {
            assertEquals(333, notification.extras.getInt(Notification.EXTRA_PROGRESS))
        }
    }

    @Test
    fun switchesToNextProgramAfterEnd() {
        val end = nowSeconds + 1200
        val notification = LiveUpdateNotification.build(context, status(nextStart = end), ((end + 60) * 1000).toLong())

        assertEquals("番組B", notification.title())
        assertNull(notification.text())
        assertEquals(((end + 3600) * 1000).toLong(), notification.`when`)
    }

    @Test
    fun endedProgramWithoutNextSaysSoAndHidesTime() {
        val notification = LiveUpdateNotification.build(context, status(), nowMillis + 1300 * 1000)

        assertEquals("番組が終わりました", notification.text())
        assertFalse(notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER))
        assertEquals(0, notification.extras.getInt(Notification.EXTRA_PROGRESS_MAX))
    }

    @Test
    fun disconnectedKeepsLastProgramAndSaysSo() {
        val notification = LiveUpdateNotification.build(context, status(isConnected = false), nowMillis)

        assertEquals("番組A", notification.title())
        assertEquals("テレビに接続できません", notification.text())
    }

    @Test
    fun recordingShowsPlaybackKeysAndElapsedTime() {
        val notification = LiveUpdateNotification.build(context, status(kind = NowPlayingKind.recorded()), nowMillis)

        assertEquals(listOf("10秒戻し", "一時停止", "30秒送り"), notification.actionTitles())
        assertEquals(nowMillis - 600 * 1000, notification.`when`)
        assertFalse(notification.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN))
        if (Build.VERSION.SDK_INT >= 36) assertEquals("録画", notification.shortCriticalText)
    }

    @Test
    fun standbyOffersOnlyPowerOn() {
        val notification = LiveUpdateNotification.build(context, status(kind = NowPlayingKind.standby(), title = ""), nowMillis)

        assertEquals("待機中", notification.title())
        assertEquals(listOf("電源を入れる"), notification.actionTitles())
    }
}
