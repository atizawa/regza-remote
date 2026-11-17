package com.example.regzaremote.liveupdate

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import com.example.regzaremote.appservices.AppContainer
import com.example.regzaremote.bridge.remoteStates
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.core.RemoteState
import com.example.regzaremote.ui.components.LiveUpdates
import java.util.Optional
import kotlin.math.abs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.future.await
import kotlinx.coroutines.launch

/**
 * ロック画面と通知の表示 (Live Updates) の開始・更新・終了。iOS の LiveActivityModel にあたる。
 * 画面と同じくリモコンの state を読み、変わったら通知と、閉じている間に起こしてもらう時刻を更新する。
 * 出しているかどうかは、通知が残っているかで決める (スワイプで消されたらオフにする)
 */
object LiveUpdateController : LiveUpdates {
    /** 通知の更新と受け取ったブロードキャストの処理は、Swift の MainActor と同じメインスレッドで順に動かす */
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private val on = MutableStateFlow(false)

    /** 通知を出しているか (設定の画面のスイッチが読む) */
    override val isOn: StateFlow<Boolean> = on.asStateFlow()

    private var observing: Job? = null

    /** 起こしてもらう時刻を予約したときの番組の終了時刻 (ミリ秒。放送でなければ null)。変わったら予約し直す */
    private var scheduledProgramEnd: Long? = null
    private var hasSchedule = false

    /** 終了時刻のずれがこれより小さければ、同じ番組として予約し直さない (取り直すたびに秒が少しずれる) */
    private const val PROGRAM_END_TOLERANCE_MILLIS = 60_000L

    /** 番組の終了から、テレビの番組情報が切り替わるのを待つ時間 */
    private const val AFTER_PROGRAM_END_MILLIS = 30_000L

    /** 放送でないときに取り直す間隔 */
    private const val IDLE_REFRESH_MILLIS = 15 * 60_000L

    /** プロセスを起こしたときに呼ぶ (AppContainer)。通知が残っていれば、見張り直す */
    fun resume(context: Context, app: RegzaAndroidApp) {
        on.value = isPosted(context)
        if (on.value) observe(context, app)
    }

    /** 設定の画面のスイッチから。通知の権限は、呼ぶ前に画面が求めておく */
    override suspend fun setEnabled(context: Context, enabled: Boolean) {
        if (!enabled) {
            stop(context)
            context.getSystemService(NotificationManager::class.java).cancel(LiveUpdateNotification.NOTIFICATION_ID)
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        LiveUpdateNotification.createChannel(context)
        val app = AppContainer.app(context)
        // つながっていないのに「接続済み」で始めないよう、先に取り直す
        app.sendRemoteActionAndWait(RemoteAction.refresh()).await()
        on.value = true
        currentState(app)?.let { show(context, it) }
        observe(context, app)
    }

    /** 通知のボタン。送り終えて表示に反映するまで待つ */
    suspend fun press(context: Context, key: RegzaKey) {
        val app = AppContainer.app(context)
        app.sendRemoteActionAndWait(RemoteAction.press(key)).await()
        if (on.value) currentState(app)?.let { show(context, it) }
    }

    /** 閉じている間に起こされたとき。取り直して通知を更新し、次を予約する */
    suspend fun refreshInBackground(context: Context) {
        hasSchedule = false
        val app = AppContainer.app(context)
        if (!on.value) return
        app.sendRemoteActionAndWait(RemoteAction.refresh()).await()
        currentState(app)?.let { show(context, it) }
    }

    /** 通知をスワイプで消されたとき。オフにしたものとして扱う */
    fun dismissed(context: Context) {
        stop(context)
    }

    private fun observe(context: Context, app: RegzaAndroidApp) {
        if (observing?.isActive == true) return
        observing = scope.launch {
            app.remoteStates().collect { state ->
                if (state != null && on.value) show(context, state)
            }
        }
    }

    private fun stop(context: Context) {
        on.value = false
        observing?.cancel()
        observing = null
        context.getSystemService(AlarmManager::class.java).cancel(LiveUpdateReceiver.refresh(context))
        hasSchedule = false
        scheduledProgramEnd = null
    }

    private fun show(context: Context, state: RemoteState) {
        val live = state.liveStatus
        val now = System.currentTimeMillis()
        context.getSystemService(NotificationManager::class.java)
            .notify(LiveUpdateNotification.NOTIFICATION_ID, LiveUpdateNotification.build(context, live, now))
        val programEnd = live.programEnd.orElse(null)?.let(LiveUpdateNotification::millis)
        if (!hasSchedule || programEndChanged(programEnd)) schedule(context, programEnd, now)
    }

    private fun programEndChanged(programEnd: Long?): Boolean {
        val scheduled = scheduledProgramEnd
        if (programEnd == null || scheduled == null) return programEnd != scheduled
        return abs(programEnd - scheduled) >= PROGRAM_END_TOLERANCE_MILLIS
    }

    /**
     * 閉じている間に起こしてもらう時刻を予約する。放送中なら番組が切り替わった直後、それ以外は 15 分後。
     * 正確な時刻のアラームは追加の権限が要り、表示が少し遅れて切り替わっても困らないので、省電力の間も起こせるものだけを使う
     */
    private fun schedule(context: Context, programEnd: Long?, now: Long) {
        val at = if (programEnd != null && programEnd > now) programEnd + AFTER_PROGRAM_END_MILLIS else now + IDLE_REFRESH_MILLIS
        context.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, LiveUpdateReceiver.refresh(context))
        hasSchedule = true
        scheduledProgramEnd = programEnd
    }

    private suspend fun currentState(app: RegzaAndroidApp): RemoteState? = app.remoteState(Optional.empty()).await().orElse(null)

    private fun isPosted(context: Context): Boolean = context.getSystemService(NotificationManager::class.java)
        .activeNotifications.any { it.id == LiveUpdateNotification.NOTIFICATION_ID }
}
