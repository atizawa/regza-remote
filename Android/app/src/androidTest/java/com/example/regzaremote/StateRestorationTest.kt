package com.example.regzaremote

import android.os.Bundle
import android.os.Parcel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.SAVED_STATE_REGISTRY_OWNER_KEY
import androidx.lifecycle.VIEW_MODEL_STORE_OWNER_KEY
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.enableSavedStateHandles
import androidx.lifecycle.viewmodel.MutableCreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.example.regzaremote.appservices.AppFactory
import com.example.regzaremote.appservices.RegzaViewModel
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppTab
import com.example.regzaremote.core.GuideSearchAction
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidStorage
import com.example.regzaremote.core.SettingsAction
import com.example.regzaremote.core.TVSetupAction
import java.util.Optional
import kotlinx.coroutines.delay
import kotlinx.coroutines.future.await
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StateRestorationTest {
    /** メモリ上の ViewModel を捨て、OS に渡す Bundle だけから新しい Swift の状態を作る。 */
    @Test
    fun savedStateRestoresDraftAndSearchIntoNewViewModel() = runBlocking {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        lateinit var owner: TestOwner
        lateinit var original: RegzaViewModel
        instrumentation.runOnMainSync {
            owner = TestOwner(null)
            original = owner.viewModel()
        }
        original.app.sendAppAction(AppAction.showSettings())
        val savedPassword = original.app.settingsState(Optional.empty()).await().get().tv.password
        original.app.sendAppAction(AppAction.selectTab(AppTab.guide()))
        original.app.sendSettingsAction(SettingsAction.tv(TVSetupAction.setHost("192.0.2.77")))
        original.app.sendSettingsAction(SettingsAction.tv(TVSetupAction.setPassword("unsaved-secret")))
        original.app.sendGuideSearchAction(GuideSearchAction.setText("復元する検索"))
        awaitDraft(original, "192.0.2.77")
        withTimeout(TIMEOUT) {
            while (original.app.guideSearchState(Optional.empty()).await().get().text != "復元する検索") delay(10)
        }
        var restoredOwner: TestOwner? = null
        lateinit var restored: RegzaViewModel
        try {
            instrumentation.runOnMainSync {
                val saved = owner.save()
                val parcel = Parcel.obtain()
                val copied = try {
                    parcel.writeBundle(saved)
                    parcel.setDataPosition(0)
                    requireNotNull(parcel.readBundle(javaClass.classLoader))
                } finally {
                    parcel.recycle()
                }
                owner.close()
                restored = TestOwner(copied).also { restoredOwner = it }.viewModel()
            }
            assertNotSame(original, restored)
            assertNotSame(original.app, restored.app)
            awaitDraft(restored, "192.0.2.77")
            assertEquals("復元する検索", restored.app.guideSearchState(Optional.empty()).await().get().text)
            assertEquals("guide", restored.app.appState(Optional.empty()).await().get().tab.rawValue)
            val settings = restored.app.settingsState(Optional.empty()).await().get()
            assertEquals(savedPassword, settings.tv.password)
            assertFalse(settings.tv.isPairing)
        } finally {
            instrumentation.runOnMainSync {
                owner.close()
                restoredOwner?.close()
            }
        }
    }

    /** 通常の Activity 再生成では、既存の ViewModel と入力をそのまま維持する。 */
    @Test
    fun activityRecreationKeepsSettingsDraft() = runBlocking {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var original: RegzaViewModel
            scenario.onActivity { activity ->
                original = ViewModelProvider(activity, AppFactory.makeViewModelFactory(activity))[RegzaViewModel::class.java]
            }
            original.app.sendAppAction(AppAction.showSettings())
            original.app.sendSettingsAction(SettingsAction.tv(TVSetupAction.setHost("192.0.2.88")))
            awaitDraft(original, "192.0.2.88")
            scenario.recreate()
            lateinit var restored: RegzaViewModel
            scenario.onActivity { activity ->
                restored = ViewModelProvider(activity, AppFactory.makeViewModelFactory(activity))[RegzaViewModel::class.java]
            }
            assertSame(original, restored)
            awaitDraft(restored, "192.0.2.88")
        }
    }

    private suspend fun awaitDraft(viewModel: RegzaViewModel, host: String) {
        withTimeout(TIMEOUT) {
            while (viewModel.app.settingsState(Optional.empty()).await().orElse(null)?.tv?.host != host) delay(10)
        }
    }

    private class TestOwner(saved: Bundle?) :
        SavedStateRegistryOwner,
        ViewModelStoreOwner {
        override val lifecycle = LifecycleRegistry(this)
        override val viewModelStore = ViewModelStore()
        private val controller = SavedStateRegistryController.create(this)
        override val savedStateRegistry get() = controller.savedStateRegistry

        init {
            controller.performAttach()
            enableSavedStateHandles()
            controller.performRestore(saved)
            lifecycle.currentState = Lifecycle.State.CREATED
        }

        fun viewModel(): RegzaViewModel {
            val factory = viewModelFactory {
                initializer {
                    RegzaViewModel(RegzaAndroidApp.sample(MemoryStorage(), "").get(), createSavedStateHandle())
                }
            }
            val extras = MutableCreationExtras().apply {
                set(SAVED_STATE_REGISTRY_OWNER_KEY, this@TestOwner)
                set(VIEW_MODEL_STORE_OWNER_KEY, this@TestOwner)
            }
            return ViewModelProvider.create(viewModelStore, factory, extras)[RegzaViewModel::class]
        }

        fun save() = Bundle().also(controller::performSave)

        fun close() {
            lifecycle.currentState = Lifecycle.State.DESTROYED
            viewModelStore.clear()
        }
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
