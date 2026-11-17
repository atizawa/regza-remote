package com.example.regzaremote.appservices.preview

import com.example.regzaremote.bridge.AppSend
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.core.RegzaAndroidApp
import java.lang.reflect.InvocationTargetException

/**
 * プレビュー用に、偽物のテレビ・録画サーバーで組み立てる。偽物は debug の APK にだけあるので (FakeApps)、名前で探して呼ぶ。
 * プレビューは本番のコードから呼ばれないので、release の APK では縮小で取り除かれる
 */
object PreviewAppFactory {
    private const val FAKE_APPS = "com.example.regzaremote.appservices.preview.FakeApps"

    fun makeApp(inEditor: Boolean, setUp: (Send) -> Unit): Pair<RegzaAndroidApp, Send> {
        val make = Class.forName(FAKE_APPS).getMethod("make", Boolean::class.javaPrimitiveType)
        // 名前で呼ぶと中の失敗が包まれるので、本当の理由 (ライブラリが読み込めないなど) を投げ直してプレビューに出す
        val app = try {
            make.invoke(null, inEditor) as RegzaAndroidApp
        } catch (error: InvocationTargetException) {
            throw error.targetException
        }
        val send = AppSend(app)
        setUp(send)
        if (inEditor) app.contractWaitUntilIdle().get()
        return app to send
    }
}
