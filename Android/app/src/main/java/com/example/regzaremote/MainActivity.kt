package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidScreen
import com.example.regzaremote.core.RegzaAndroidSetup
import com.example.regzaremote.core.RegzaAndroidSnapshot

/** 設定を開いていれば設定の画面、そうでなければタブの画面 */
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
                    if (setup != null) SetupScreen(setup, model::send) else AppScreen(state, model.screen, model::send)
                }
            }
        }
    }
}

/** 画面から送る操作 */
typealias Send = (RegzaAndroidAction) -> Unit

/**
 * 設定 (iOS の設定と同じ TVSetupViewModel・ServerSetupViewModel)。
 * テレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト・番組表 (Mirakurun) のアドレス
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
        Text("設定", style = MaterialTheme.typography.titleLarge)
        SectionTitle("テレビ")
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
        setup.scanMessage.orElse(null)?.let { Note(it) }

        // PIN で登録
        if (!setup.isWaitingForPIN) {
            Button(onClick = { send(RegzaAndroidAction.startPairing()) }, enabled = setup.host.isNotBlank() && !setup.isPairing) {
                Text(if (setup.isRegistered) "もう一度登録する" else "テレビに PIN を表示")
            }
            Note("テレビの電源を入れてからボタンを押すと、テレビの画面に PIN が表示されます。")
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
        setup.pairingMessage.orElse(null)?.let { Note(it) }

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
            Note("テレビの「外部連携設定」で設定したユーザー名とパスワードを入力してください。")
        }
        OutlinedButton(onClick = { send(RegzaAndroidAction.test()) }, enabled = setup.host.isNotBlank() && !setup.isTesting) {
            Text("接続テスト")
        }
        setup.testResult.orElse(null)?.let { Note(it) }

        // 番組表 (Mirakurun)
        SectionTitle("番組表 (Mirakurun)")
        SyncedTextField(
            value = setup.guideHost, onValueChange = { send(RegzaAndroidAction.setGuideHost(it)) },
            label = "Mirakurun のアドレス (例: 192.168.0.2)",
        )
        if (!setup.isGuideHostValid) {
            Text("ポートは 1〜65535 の数字で入れてください。", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
        setup.guideHosts.forEach { host ->
            Row(
                modifier = Modifier.fillMaxWidth().clickable { send(RegzaAndroidAction.setGuideHost(host)) }.padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(host, Modifier.weight(1f))
                if (host == setup.guideHost) Text("✓", color = MaterialTheme.colorScheme.primary)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            OutlinedButton(onClick = { send(RegzaAndroidAction.scanGuide()) }, enabled = !setup.isScanningGuide) {
                Text(if (setup.isScanningGuide) "Mirakurun を探しています…" else "Mirakurun を探す")
            }
            if (setup.isGuideLinked) {
                TextButton(onClick = { send(RegzaAndroidAction.unlinkGuide()) }) {
                    Text("連携を解除", color = MaterialTheme.colorScheme.error)
                }
            }
        }
        setup.guideMessage.orElse(null)?.let { Note(it) }
        Note("Mirakurun を動かしている場合に設定すると、番組名・番組表・番組表からの録画予約が使えます。使わない場合は空のままにしてください。")

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(onClick = { send(RegzaAndroidAction.save()) }, enabled = setup.isCanSave) { Text("保存") }
            if (setup.isCanClose) {
                TextButton(onClick = { send(RegzaAndroidAction.closeSetup()) }) { Text("閉じる") }
            }
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(text, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
}

/** 補足の説明 */
@Composable
fun Note(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

/**
 * 入力欄。打った文字はこの画面ですぐに出し、Swift の ViewModel には操作として送る。
 * ViewModel から別の値が来たとき (見つけたテレビを選んだときなど) だけ、その値に入れ替える
 * (送った値が遅れて戻ってきても、打っている途中の文字を巻き戻さない)
 */
@Composable
fun SyncedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier.fillMaxWidth(),
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
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        modifier = modifier,
    )
}

/** 画面の上の見出し。タブの中で開いた画面なら、戻るボタンも出す */
@Composable
fun ScreenHeader(title: String, onBack: (() -> Unit)? = null, actions: @Composable RowScope.() -> Unit = {}) {
    Row(
        modifier = Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) TextButton(onClick = onBack) { Text("‹ 戻る") } else Spacer(Modifier.padding(start = 12.dp))
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f).padding(horizontal = 4.dp), maxLines = 1)
        actions()
    }
}

/** 登録したあとの画面。iOS 版と同じく、下のタブで画面を切り替える (タブと戻る道も AppViewModel が持つ) */
@Composable
private fun AppScreen(state: RegzaAndroidSnapshot, screen: RegzaAndroidScreen?, send: Send) {
    // 画面が見えている間だけ、いま映っているものを取り直す (チャンネルのタブでも、いま見ている局の印に使う)。
    // 裏に回ったらテレビに問い合わせない
    LifecycleStartEffect(Unit) {
        send(RegzaAndroidAction.startPolling())
        onStopOrDispose { send(RegzaAndroidAction.stopPolling()) }
    }
    // タブの中で開いた画面は、戻るボタンで 1 つ戻る
    BackHandler(enabled = state.isCanGoBack) { send(RegzaAndroidAction.back()) }
    val tab = state.tab
    val back = if (state.isCanGoBack) ({ send(RegzaAndroidAction.back()) }) else null
    Scaffold(
        bottomBar = {
            NavigationBar {
                TabItem("remote", "リモコン", Icons.Filled.Home, tab, send)
                TabItem("guide", "番組表", Icons.Filled.DateRange, tab, send)
                TabItem("channels", "チャンネル", Icons.AutoMirrored.Filled.List, tab, send)
                TabItem("reservations", "録画予約", Icons.Filled.Star, tab, send)
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (screen?.kind) {
                "guide" -> screen.guide.orElse(null)?.let { GuideScreen(it, send) }
                "channels" -> screen.channelList.orElse(null)?.let { ChannelScreen(it, send) }
                "reservations" -> screen.reservations.orElse(null)?.let { ReservationsScreen(it, send) }
                "programs" -> screen.programs.orElse(null)?.let { ProgramListScreen(it, back, send) }
                "detail" -> screen.detail.orElse(null)?.let { ProgramDetailScreen(it, back, send) }
                "search" -> screen.search.orElse(null)?.let { SearchScreen(it, back, send) }
                else -> RemoteScreen(state, send)
            }
        }
    }
}

@Composable
private fun RowScope.TabItem(
    name: String,
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    selected: String,
    send: Send,
) {
    NavigationBarItem(
        selected = selected == name, onClick = { send(RegzaAndroidAction.selectTab(name)) },
        icon = { Icon(icon, contentDescription = null) }, label = { Text(label) },
    )
}
