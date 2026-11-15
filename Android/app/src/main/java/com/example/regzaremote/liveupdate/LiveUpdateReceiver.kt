package com.example.regzaremote.liveupdate

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.regzaremote.core.RegzaKey
import kotlinx.coroutines.launch

/**
 * 通知のボタン・閉じている間の更新のアラーム・通知を消されたことを受け取る。
 * アプリが止まっていてもプロセスを起こしてもらえるので、送信と通知の更新が終わるまで待ってから返す (goAsync)
 */
class LiveUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        val pending = goAsync()
        LiveUpdateController.scope.launch {
            try {
                when (intent.action) {
                    ACTION_PRESS -> intent.getStringExtra(EXTRA_KEY)
                        ?.let { RegzaKey.`init`(it).orElse(null) }
                        ?.let { LiveUpdateController.press(appContext, it) }

                    ACTION_REFRESH -> LiveUpdateController.refreshInBackground(appContext)

                    ACTION_DISMISSED -> LiveUpdateController.dismissed(appContext)
                }
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val ACTION_PRESS = "com.example.regzaremote.liveupdate.PRESS"
        private const val ACTION_REFRESH = "com.example.regzaremote.liveupdate.REFRESH"
        private const val ACTION_DISMISSED = "com.example.regzaremote.liveupdate.DISMISSED"
        private const val EXTRA_KEY = "key"

        /** 通知のボタン。キーごとに別の PendingIntent にする (同じ番号だと、あとのキーで上書きされる) */
        fun press(context: Context, key: RegzaKey): PendingIntent = broadcast(
            context,
            key.rawValue.hashCode(),
            Intent(context, LiveUpdateReceiver::class.java).setAction(ACTION_PRESS).putExtra(EXTRA_KEY, key.rawValue),
        )

        fun refresh(context: Context): PendingIntent =
            broadcast(context, 0, Intent(context, LiveUpdateReceiver::class.java).setAction(ACTION_REFRESH))

        fun dismissed(context: Context): PendingIntent =
            broadcast(context, 0, Intent(context, LiveUpdateReceiver::class.java).setAction(ACTION_DISMISSED))

        private fun broadcast(context: Context, requestCode: Int, intent: Intent): PendingIntent =
            PendingIntent.getBroadcast(context, requestCode, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }
}
