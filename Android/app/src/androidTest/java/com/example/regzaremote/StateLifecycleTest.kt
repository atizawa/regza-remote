package com.example.regzaremote

import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.regzaremote.bridge.AppSend
import com.example.regzaremote.bridge.appStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppTab
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidStorage
import com.example.regzaremote.ui.components.rememberState
import java.util.Optional
import kotlinx.coroutines.delay
import kotlinx.coroutines.future.await
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Compose の購読停止・再開が JNI 越しの Swift 待機に届くことを確かめる。 */
@RunWith(AndroidJUnit4::class)
class StateLifecycleTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun stoppedScreenReleasesWaitAndReceivesLatestStateOnRestart() = runBlocking {
        val app = RegzaAndroidApp.sample(MemoryStorage(), "").get()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        lateinit var owner: TestLifecycleOwner
        instrumentation.runOnMainSync {
            owner = TestLifecycleOwner()
            owner.lifecycle.currentState = Lifecycle.State.STARTED
        }
        try {
            compose.setContent {
                CompositionLocalProvider(LocalLifecycleOwner provides owner) {
                    val state = rememberState(app) { app.appStates() }
                    Text(state?.tab?.rawValue ?: "loading")
                }
            }
            awaitText(AppTab.remote().rawValue)
            awaitWaitCount(app, 1)

            instrumentation.runOnMainSync { owner.lifecycle.currentState = Lifecycle.State.CREATED }
            awaitWaitCount(app, 0)
            AppSend(app)(AppAction.selectTab(AppTab.guide()))
            withTimeout(TIMEOUT) {
                while (app.appState(Optional.empty()).await().get().tab.rawValue != AppTab.guide().rawValue) delay(10)
            }
            compose.onNodeWithText(AppTab.remote().rawValue).assertExists()

            instrumentation.runOnMainSync { owner.lifecycle.currentState = Lifecycle.State.STARTED }
            awaitText(AppTab.guide().rawValue)
            awaitWaitCount(app, 1)
        } finally {
            instrumentation.runOnMainSync { owner.lifecycle.currentState = Lifecycle.State.DESTROYED }
            awaitWaitCount(app, 0)
        }
    }

    private fun awaitText(text: String) {
        compose.waitUntil(timeoutMillis = TIMEOUT) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    private suspend fun awaitWaitCount(app: RegzaAndroidApp, expected: Long) {
        withTimeout(TIMEOUT) {
            while (app.pendingStateWaitCount().await() != expected) delay(10)
        }
    }

    private class TestLifecycleOwner : LifecycleOwner {
        override val lifecycle = LifecycleRegistry(this)
    }

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
