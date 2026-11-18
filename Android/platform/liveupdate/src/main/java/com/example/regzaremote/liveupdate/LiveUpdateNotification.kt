package com.example.regzaremote.liveupdate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import com.example.regzaremote.core.Date
import com.example.regzaremote.core.LiveHeadline
import com.example.regzaremote.core.LiveStatus
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.design.R as DesignR
import com.example.regzaremote.localization.R as StringsR

/**
 * 共有の LiveStatus から通知を組み立てる。Android 16 以上では Live Updates (ステータスバーのチップ・ロック画面) に昇格を頼み、
 * それより前は同じ内容を常駐の通知として出す。昇格の条件に合わせ、見た目は標準の通知の形だけを使う (自前のレイアウトや色付けはしない)
 */
object LiveUpdateNotification {
    const val CHANNEL_ID = "live_update"
    const val NOTIFICATION_ID = 1

    /** 進み具合を、この細かさの整数で渡す */
    private const val PROGRESS_MAX = 1000

    /** 見出しの上に出すテレビの名前 (iOS の Live Activity と同じ) */
    private const val TV_NAME = "REGZA"

    fun createChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(StringsR.string.live_update_channel_name),
            // 音を鳴らさずに出し続ける (最低の重要度だと昇格できない)
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(StringsR.string.live_update_channel_description)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    /** nowMillis の時点で出す通知。番組が終わっていれば、分かる範囲で次の番組に切り替えて出す */
    fun build(context: Context, live: LiveStatus, nowMillis: Long): Notification {
        val now = Date.`init`(nowMillis / 1000.0)
        val status = live.displayed(false, now)
        val hasEnded = status.hasProgramEnded(false, now)
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_live_update)
            .setContentTitle(headline(context, status))
            .setSubText(status.headerName(TV_NAME))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(openApp(context))
            .setDeleteIntent(LiveUpdateReceiver.dismissed(context))
        detail(context, status, hasEnded)?.let(builder::setContentText)
        setTime(builder, status, hasEnded)
        status.compactKeys.forEach { builder.addAction(action(context, it)) }

        val showsTimeline = status.isHasTimeline && !hasEnded
        val progress = (status.progress(now) * PROGRESS_MAX).toInt()
        if (Build.VERSION.SDK_INT >= 36) {
            builder.setShortCriticalText(chip(context, status))
            builder.setRequestPromotedOngoing(true)
            if (showsTimeline) {
                builder.setStyle(
                    Notification.ProgressStyle()
                        .setProgressSegments(listOf(Notification.ProgressStyle.Segment(PROGRESS_MAX)))
                        .setProgress(progress),
                )
            }
        } else if (showsTimeline) {
            builder.setProgress(PROGRESS_MAX, progress, false)
        }
        return builder.build()
    }

    private fun headline(context: Context, status: LiveStatus): String = when (status.headline.discriminator) {
        LiveHeadline.Discriminator.PROGRAM -> status.title
        LiveHeadline.Discriminator.CHANNEL -> status.channelName
        LiveHeadline.Discriminator.EXTERNAL -> context.getString(StringsR.string.live_status_external)
        LiveHeadline.Discriminator.STANDBY -> context.getString(StringsR.string.live_status_standby)
        LiveHeadline.Discriminator.DISCONNECTED -> context.getString(StringsR.string.live_status_disconnected)
        LiveHeadline.Discriminator.SENTCOMMAND -> context.getString(StringsR.string.live_status_sent_command, status.lastCommand.orElse(""))
        LiveHeadline.Discriminator.REMOTE -> context.getString(StringsR.string.live_status_remote)
    }

    /** 見出しの下の行。番組が終わったこと・つながらないこと・チャプター・ジャンルの順に、1 つだけ出す */
    private fun detail(context: Context, status: LiveStatus, hasEnded: Boolean): String? = when {
        hasEnded -> context.getString(StringsR.string.live_status_program_ended)

        // 直前の情報を出しているときは、つながっていないことを添える
        !status.isConnected && status.isHasInfoHeadline -> context.getString(StringsR.string.live_status_disconnected)

        status.headline.discriminator == LiveHeadline.Discriminator.PROGRAM -> status.chapterName.ifEmpty { null }

        // 番組名が取れない機種では、ジャンルで何の番組かを示す
        status.headline.discriminator == LiveHeadline.Discriminator.CHANNEL -> status.genre.ifEmpty { null }

        else -> null
    }

    /** ステータスバーのチップに出す短い文字。録画は「録画」、放送は短い局名 */
    private fun chip(context: Context, status: LiveStatus): String? = when {
        status.isRecordingPlayback -> context.getString(StringsR.string.live_status_recording)
        status.shortChannel.isNotEmpty() -> status.shortChannel
        else -> null
    }

    /**
     * 時間の表示。進捗のバーはアプリが更新しないと進まないので、残り時間 (放送) と経過時間 (録画) は
     * システムが進める時計で出す
     */
    private fun setTime(builder: Notification.Builder, status: LiveStatus, hasEnded: Boolean) {
        val end = status.programEnd.orElse(null)
        val start = status.playbackStart.orElse(null)
        when {
            hasEnded -> builder.setShowWhen(false)
            end != null -> builder.setWhen(millis(end)).setUsesChronometer(true).setChronometerCountDown(true).setShowWhen(true)
            start != null -> builder.setWhen(millis(start)).setUsesChronometer(true).setChronometerCountDown(false).setShowWhen(true)
            else -> builder.setShowWhen(false)
        }
    }

    private fun action(context: Context, key: RegzaKey): Notification.Action {
        // 待機中に出す唯一のボタンなので、何をするか文字で添える
        val label = if (key.discriminator == RegzaKey.Discriminator.POWER) context.getString(StringsR.string.remote_power_on) else key.label
        return Notification.Action.Builder(Icon.createWithResource(context, icon(key)), label, LiveUpdateReceiver.press(context, key))
            .build()
    }

    private fun icon(key: RegzaKey): Int = when (key.discriminator) {
        RegzaKey.Discriminator.POWER -> DesignR.drawable.widget_key_power
        RegzaKey.Discriminator.MUTE -> DesignR.drawable.widget_key_mute
        RegzaKey.Discriminator.PLAY -> DesignR.drawable.widget_key_play
        RegzaKey.Discriminator.PAUSE -> DesignR.drawable.widget_key_pause
        RegzaKey.Discriminator.SKIPBACKWARD -> DesignR.drawable.widget_key_replay
        RegzaKey.Discriminator.SKIPFORWARD -> DesignR.drawable.widget_key_forward
        else -> R.drawable.ic_live_update
    }

    /** アプリを開く。起動の画面はアプリ本体にあるので、OS に登録した起動の入口 (ランチャーから開くのと同じもの) を使う */
    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        checkNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    fun millis(date: Date): Long = (date.timeIntervalSince1970 * 1000).toLong()
}
