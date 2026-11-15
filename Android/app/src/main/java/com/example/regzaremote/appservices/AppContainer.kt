package com.example.regzaremote.appservices

import android.content.Context
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.liveupdate.LiveUpdateController

/**
 * プロセスに 1 つだけ置く Swift の窓口。画面・通知のボタン・閉じている間の更新が同じものを使うので、
 * 通知から送った操作も画面の state に、画面の操作も通知に、そのまま反映される (iOS の AppContainer と同じ)
 */
object AppContainer {
    @Volatile private var app: RegzaAndroidApp? = null

    /** 窓口を返す。プロセスで最初に呼ばれたときに作り、通知が残っていれば見張り直す。メインスレッドから呼ぶ */
    fun app(context: Context): RegzaAndroidApp = app ?: synchronized(this) {
        app ?: AppFactory.makeApp(context.applicationContext).also { created ->
            app = created
            LiveUpdateController.resume(context.applicationContext, created)
        }
    }
}
