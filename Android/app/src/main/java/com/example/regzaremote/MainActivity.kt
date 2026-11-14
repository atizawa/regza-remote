package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.regzaremote.appservices.AppFactory
import com.example.regzaremote.appservices.RegzaViewModel
import com.example.regzaremote.bridge.appStates
import com.example.regzaremote.bridge.livePlayerStates
import com.example.regzaremote.bridge.settingsStates
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.AppearanceTheme
import com.example.regzaremote.ui.components.LocalNetworkGate
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.AppScreen
import com.example.regzaremote.ui.screens.LivePlayerScreen
import com.example.regzaremote.ui.screens.SettingsScreen

/** 設定を開いていれば設定の画面、そうでなければタブの画面 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val testServer = if (BuildConfig.DEBUG) intent.getStringExtra("UITestServer") else null
        setContent {
            // 色リソースとMaterialの配色をOSの外観に合わせる
            MaterialTheme(colorScheme = AppTheme.colorScheme) {
                Surface(modifier = Modifier.fillMaxSize().semantics { testTagsAsResourceId = true }, color = AppTheme.background) {
                    // テレビは同じ LAN にあるので、ローカルネットワークへのアクセスを許可されてから画面を出す
                    LocalNetworkGate {
                        val appViewModelFactory = remember { AppFactory.makeViewModelFactory(applicationContext, testServer) }
                        val regzaViewModel: RegzaViewModel = viewModel(factory = appViewModelFactory)
                        val app = regzaViewModel.app
                        val state = rememberState(app) { app.appStates() } ?: return@LocalNetworkGate
                        AppearanceTheme(state.appearance.rawValue) {
                            Surface(modifier = Modifier.fillMaxSize(), color = AppTheme.background) {
                                // 設定は開いている間だけ state が届く
                                val settings = rememberState(app) { app.settingsStates() }
                                if (settings !=
                                    null
                                ) {
                                    SettingsScreen(settings, regzaViewModel.send)
                                } else {
                                    AppScreen(app, state, regzaViewModel.send)
                                }
                                // アプリで見る (ライブ視聴) は、どの画面の上にも全画面で重ねる
                                rememberState(app) { app.livePlayerStates() }?.let { LivePlayerScreen(it, regzaViewModel.send) }
                            }
                        }
                    }
                }
            }
        }
    }
}
