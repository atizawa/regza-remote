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
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.liveupdate.LiveUpdateController
import com.example.regzaremote.ui.app.AppRoot
import com.example.regzaremote.ui.components.LocalNetworkGate
import com.example.regzaremote.ui.components.rememberState

/** アプリの入口。ローカルネットワークの許可を待ってから、組み立て (ui.app の AppRoot) に画面を任せる */
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
                        // Live Updates の実装はアプリ本体にあるので、組み立てに渡す (iOS の RootView が Live Activity を AppScreen に渡すのと同じ)
                        AppRoot(app, state, regzaViewModel.send, LiveUpdateController)
                    }
                }
            }
        }
    }
}
