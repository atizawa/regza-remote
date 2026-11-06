package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.viewmodel.compose.viewModel

/** 登録していなければ PIN で登録する画面、登録していればリモコンの画面 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // iOS 版と同じくダークにそろえる
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val model: RegzaViewModel = viewModel()
                    if (model.connection != null) AppScreen(model) else RegistrationScreen(model)
                }
            }
        }
    }
}

@Composable
private fun RegistrationScreen(model: RegzaViewModel) {
    // 入力中の文字は、画面の回転などで Activity が作り直されても残す
    var host by rememberSaveable { mutableStateOf("") }
    var pin by rememberSaveable { mutableStateOf("") }

    Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (model.pairing == null) {
            Text("テレビを登録する", style = MaterialTheme.typography.titleLarge)
            OutlinedTextField(
                value = host,
                onValueChange = { host = it },
                label = { Text("テレビのアドレス") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(onClick = {
                pin = ""
                model.startPairing(host.trim())
            }, enabled = host.isNotBlank() && !model.isBusy) { Text("テレビに PIN を表示") }
        } else {
            Text("テレビに表示された PIN を入力", style = MaterialTheme.typography.titleLarge)
            OutlinedTextField(
                value = pin,
                onValueChange = { pin = it },
                label = { Text("PIN") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(onClick = { model.confirmPairing(pin.trim()) }, enabled = pin.isNotBlank() && !model.isBusy) { Text("登録") }
                OutlinedButton(onClick = { model.cancelPairing() }, enabled = !model.isBusy) { Text("やめる") }
            }
        }
        if (model.message.isNotEmpty()) Text(model.message)
    }
}

/** 登録したあとの画面。iOS 版と同じく、下のタブでリモコンとチャンネルを切り替える */
@Composable
private fun AppScreen(model: RegzaViewModel) {
    // 画面が見えている間だけ、いま映っているものを取り直す (チャンネルのタブでも、いま見ている局の印に使う)。
    // 裏に回ったらテレビに問い合わせない
    LifecycleStartEffect(model) {
        model.startPolling()
        onStopOrDispose { model.stopPolling() }
    }
    var tab by rememberSaveable { mutableStateOf(Tab.Remote) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = tab == Tab.Remote, onClick = { tab = Tab.Remote },
                    icon = { Icon(Icons.Filled.Home, contentDescription = null) }, label = { Text("リモコン") },
                )
                NavigationBarItem(
                    selected = tab == Tab.Channels, onClick = { tab = Tab.Channels },
                    icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) }, label = { Text("チャンネル") },
                )
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                Tab.Remote -> RemoteScreen(model)
                Tab.Channels -> ChannelScreen(model)
            }
        }
    }
}

private enum class Tab { Remote, Channels }
