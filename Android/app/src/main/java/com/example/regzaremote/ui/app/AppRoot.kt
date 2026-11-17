package com.example.regzaremote.ui.app

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.livePlayerStates
import com.example.regzaremote.bridge.settingsStates
import com.example.regzaremote.core.AppAppearance
import com.example.regzaremote.core.AppState
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.AppearanceTheme
import com.example.regzaremote.liveupdate.LiveUpdateController
import com.example.regzaremote.ui.components.LocalLiveUpdates
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.feature.player.LivePlayerScreen
import com.example.regzaremote.ui.feature.settings.SettingsScreen

/** アプリのいちばん外側の画面。設定を開いていれば設定の画面、そうでなければタブの画面。ライブ視聴はどの画面の上にも重ねる */
@Composable
fun AppRoot(app: RegzaAndroidApp, state: AppState, send: Send) {
    // Live Updates のスイッチ (共通の部品) に、アプリの実装を渡す
    CompositionLocalProvider(LocalLiveUpdates provides LiveUpdateController) {
        AppearanceTheme(state.appearance.isDark) {
            Surface(modifier = Modifier.fillMaxSize(), color = AppTheme.background) {
                // 設定は開いている間だけ state が届く
                val settings = rememberState(app) { app.settingsStates() }
                if (settings != null) {
                    SettingsScreen(settings, send)
                } else {
                    AppScreen(app, state, send)
                }
                // アプリで見る (ライブ視聴) は、どの画面の上にも全画面で重ねる
                rememberState(app) { app.livePlayerStates() }?.let { LivePlayerScreen(it, send) }
            }
        }
    }
}

/** 外観の選択を、AppearanceTheme に渡す形にする (null はシステムに合わせる) */
private val AppAppearance.isDark: Boolean?
    get() = when (discriminator) {
        AppAppearance.Discriminator.LIGHT -> false
        AppAppearance.Discriminator.DARK -> true
        AppAppearance.Discriminator.SYSTEM -> null
    }
