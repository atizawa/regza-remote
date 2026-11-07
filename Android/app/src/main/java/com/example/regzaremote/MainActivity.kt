package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidSetup
import com.example.regzaremote.core.RegzaAndroidSnapshot

/** 登録の画面を出していればテレビの登録の画面、そうでなければリモコンとチャンネルの画面 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // iOS 版と同じくダークにそろえる
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val model: RegzaViewModel = viewModel()
                    val state = model.state ?: return@Surface
                    val setup = state.setup.orElse(null)
                    if (setup != null) SetupScreen(setup, model::send) else AppScreen(state, model::send)
                }
            }
        }
    }
}

/** 画面から送る操作 */
typealias Send = (RegzaAndroidAction) -> Unit

/**
 * テレビの登録 (iOS の設定の「REGZA」の画面と同じ TVSetupViewModel)。
 * 同じネットワークのテレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
 */
@Composable
private fun SetupScreen(setup: RegzaAndroidSetup, send: Send) {
    // 未登録なら開いたときに探し始める
    LaunchedEffect(Unit) { send(RegzaAndroidAction.setupAppear()) }
    // PIN で登録できたら (保存も済んでいる) 閉じる
    LaunchedEffect(setup.isHasRegistered) { if (setup.isHasRegistered) send(RegzaAndroidAction.closeSetup()) }
    // 登録済みのテレビがあれば、戻るボタンでも閉じる (PIN の表示中なら、テレビの PIN 表示も消す)
    BackHandler(enabled = setup.isCanClose) { send(RegzaAndroidAction.closeSetup()) }
    val isBusy = setup.isPairing || setup.isWaitingForPIN

    Column(
        modifier = Modifier.verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("テレビを登録する", style = MaterialTheme.typography.titleLarge)
        SyncedTextField(
            value = setup.host, onValueChange = { send(RegzaAndroidAction.setHost(it)) },
            label = "テレビの IP アドレス", enabled = !setup.isWaitingForPIN,
        )
        setup.devices.forEach { device ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(enabled = !isBusy) { send(RegzaAndroidAction.selectDevice(device.host)) }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text(device.name)
                    Text(device.host, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (device.isSelected) Text("✓", color = MaterialTheme.colorScheme.primary)
            }
            HorizontalDivider()
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = { send(RegzaAndroidAction.scan()) }, enabled = !setup.isScanning && !setup.isWaitingForPIN) {
                Text(if (setup.isScanning) "テレビを探しています…" else "テレビを探す")
            }
            if (setup.isScanning) CircularProgressIndicator(Modifier.padding(4.dp), strokeWidth = 2.dp)
        }
        setup.scanMessage.orElse(null)?.let { Text(it, style = MaterialTheme.typography.bodySmall) }

        // PIN で登録
        if (!setup.isWaitingForPIN) {
            Button(onClick = { send(RegzaAndroidAction.startPairing()) }, enabled = setup.host.isNotBlank() && !setup.isPairing) {
                Text(if (setup.isRegistered) "もう一度登録する" else "テレビに PIN を表示")
            }
            Text("テレビの電源を入れてからボタンを押すと、テレビの画面に PIN が表示されます。", style = MaterialTheme.typography.bodySmall)
        } else {
            SyncedTextField(
                value = setup.pin, onValueChange = { send(RegzaAndroidAction.setPIN(it)) },
                label = "テレビに表示された PIN", keyboardType = KeyboardType.NumberPassword,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(onClick = { send(RegzaAndroidAction.confirmPairing()) }, enabled = setup.pin.isNotBlank() && !setup.isPairing) {
                    Text("登録")
                }
                OutlinedButton(onClick = { send(RegzaAndroidAction.cancelPairing()) }, enabled = !setup.isPairing) { Text("やめる") }
            }
        }
        setup.pairingMessage.orElse(null)?.let { Text(it, style = MaterialTheme.typography.bodySmall) }

        // PIN 登録に対応していない古い機種
        TextButton(onClick = { send(RegzaAndroidAction.setShowingManualEntry(!setup.isShowingManualEntry)) }) {
            Text("ユーザー名とパスワードを入力")
        }
        if (setup.isShowingManualEntry) {
            SyncedTextField(value = setup.user, onValueChange = { send(RegzaAndroidAction.setUser(it)) }, label = "ユーザー名")
            SyncedTextField(
                value = setup.password, onValueChange = { send(RegzaAndroidAction.setPassword(it)) },
                label = "パスワード", isPassword = true,
            )
            Text("テレビの「外部連携設定」で設定したユーザー名とパスワードを入力してください。", style = MaterialTheme.typography.bodySmall)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = { send(RegzaAndroidAction.test()) }, enabled = setup.host.isNotBlank() && !setup.isTesting) {
                Text("接続テスト")
            }
            Button(onClick = { send(RegzaAndroidAction.save()) }, enabled = setup.isCanSave) { Text("保存") }
            if (setup.isCanClose) {
                TextButton(onClick = { send(RegzaAndroidAction.closeSetup()) }) { Text("閉じる") }
            }
        }
        setup.testResult.orElse(null)?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
    }
}

/**
 * 入力欄。打った文字はこの画面ですぐに出し、Swift の ViewModel には操作として送る。
 * ViewModel から別の値が来たとき (見つけたテレビを選んだときなど) だけ、その値に入れ替える
 * (送った値が遅れて戻ってきても、打っている途中の文字を巻き戻さない)
 */
@Composable
private fun SyncedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    enabled: Boolean = true,
    keyboardType: KeyboardType = KeyboardType.Text,
    isPassword: Boolean = false,
) {
    var text by remember { mutableStateOf(value) }
    val sent = remember { mutableListOf<String>() }
    LaunchedEffect(value) {
        if (value in sent) {
            // 送った値が戻ってきた。最後に送った値まで戻ってきたら、覚えておく必要はない
            if (value == sent.last()) sent.clear()
        } else {
            text = value
        }
    }
    OutlinedTextField(
        value = text,
        onValueChange = {
            text = it
            sent.add(it)
            onValueChange(it)
        },
        label = { Text(label) },
        singleLine = true,
        enabled = enabled,
        keyboardOptions = KeyboardOptions(keyboardType = if (isPassword) KeyboardType.Password else keyboardType),
        visualTransformation = if (isPassword) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        modifier = Modifier.fillMaxWidth(),
    )
}

/** 登録したあとの画面。iOS 版と同じく、下のタブでリモコンとチャンネルを切り替える (タブも AppViewModel が持つ) */
@Composable
private fun AppScreen(state: RegzaAndroidSnapshot, send: Send) {
    // 画面が見えている間だけ、いま映っているものを取り直す (チャンネルのタブでも、いま見ている局の印に使う)。
    // 裏に回ったらテレビに問い合わせない
    LifecycleStartEffect(Unit) {
        send(RegzaAndroidAction.startPolling())
        onStopOrDispose { send(RegzaAndroidAction.stopPolling()) }
    }
    val tab = state.tab
    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = tab == "remote", onClick = { send(RegzaAndroidAction.selectTab("remote")) },
                    icon = { Icon(Icons.Filled.Home, contentDescription = null) }, label = { Text("リモコン") },
                )
                NavigationBarItem(
                    selected = tab == "channels", onClick = { send(RegzaAndroidAction.selectTab("channels")) },
                    icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) }, label = { Text("チャンネル") },
                )
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                "channels" -> ChannelScreen(state, send)
                // Android にまだない番組表と録画のタブは、リモコンを出す
                else -> RemoteScreen(state, send)
            }
        }
    }
}
