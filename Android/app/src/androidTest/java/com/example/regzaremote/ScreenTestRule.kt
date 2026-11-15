package com.example.regzaremote

import android.Manifest
import android.app.KeyguardManager
import android.os.Build
import android.os.SystemClock
import androidx.test.platform.app.InstrumentationRegistry
import java.io.FileInputStream
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runners.model.Statement

/**
 * 画面を出すテストの準備。端末の状態のせいで落ちたのか、アプリのせいで落ちたのかを見分けられるようにする。
 *
 * - 画面を点け、パスワードなどのないロックなら外す。それでもロックされていれば、ロックを解除するよう伝えて落とす
 *   (ロックされたままだと Activity が前に出られず、関係のない理由で落ちる)
 * - Android 17 から、ローカルネットワークへのアクセスを許可しておく。許可がないと、アプリは最初に許可のダイアログを出し
 *   (LocalNetworkGate)、ダイアログが Activity の上にかぶって、テストが Activity を前に出せずに止まる
 */
class ScreenTestRule : TestRule {
    override fun apply(base: Statement, description: Description): Statement = object : Statement() {
        override fun evaluate() {
            val instrumentation = InstrumentationRegistry.getInstrumentation()
            val context = instrumentation.targetContext
            shell("input keyevent KEYCODE_WAKEUP")
            shell("wm dismiss-keyguard")
            val keyguard = context.getSystemService(KeyguardManager::class.java)
            val deadline = SystemClock.uptimeMillis() + UNLOCK_TIMEOUT_MILLIS
            while (keyguard.isKeyguardLocked && SystemClock.uptimeMillis() < deadline) SystemClock.sleep(100)
            check(!keyguard.isKeyguardLocked) { "端末がロックされています。ロックを解除して、画面を点けたままにしてからテストを実行してください" }
            if (Build.VERSION.SDK_INT >= 37) {
                instrumentation.uiAutomation.grantRuntimePermission(context.packageName, Manifest.permission.ACCESS_LOCAL_NETWORK)
            }
            base.evaluate()
        }
    }

    /** シェルのコマンドを実行し、終わるまで待つ (出力を読み切らないと、終わる前に次へ進む) */
    private fun shell(command: String) {
        InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command).use { output ->
            FileInputStream(output.fileDescriptor).use { it.readBytes() }
        }
    }

    private companion object {
        const val UNLOCK_TIMEOUT_MILLIS = 2_000L
    }
}
