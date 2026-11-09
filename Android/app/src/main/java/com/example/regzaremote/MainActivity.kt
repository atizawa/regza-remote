package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.core.RegzaAndroidScreen
import com.example.regzaremote.core.RegzaAndroidSnapshot

/** 設定を開いていれば設定の画面、そうでなければタブの画面 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // iOS 版と同じくダークに固定し、強調色を緑にする
            MaterialTheme(colorScheme = AppTheme.colorScheme) {
                Surface(modifier = Modifier.fillMaxSize(), color = AppTheme.background) {
                    // テレビは同じ LAN にあるので、ローカルネットワークへのアクセスを許可されてから画面を出す
                    LocalNetworkGate {
                        val model: RegzaViewModel = viewModel()
                        val state = model.state ?: return@LocalNetworkGate
                        val setup = state.setup.orElse(null)
                        if (setup != null) SettingsScreen(setup, model.send) else AppScreen(state, model.screen, model.send)
                        // アプリで見る (ライブ視聴) は、どの画面の上にも全画面で重ねる
                        state.player.orElse(null)?.let { LivePlayerScreen(it, model.send) }
                    }
                }
            }
        }
    }
}

/**
 * 入力欄の文字。打った文字はこの画面ですぐに出し、Swift の ViewModel には操作として送る。
 * ViewModel から別の値が来たとき (見つけたテレビを選んだときなど) だけ、その値に入れ替える
 * (送った値が遅れて戻ってきても、打っている途中の文字を巻き戻さない)
 */
class SyncedText(private val text: MutableState<String>) {
    private val sent = mutableListOf<String>()
    val value: String get() = text.value

    fun update(value: String, send: (String) -> Unit) {
        text.value = value
        sent.add(value)
        send(value)
    }

    fun received(value: String) {
        if (value in sent) {
            // 送った値が戻ってきた。最後に送った値まで戻ってきたら、覚えておく必要はない
            if (value == sent.last()) sent.clear()
        } else {
            text.value = value
        }
    }
}

@Composable
fun rememberSyncedText(value: String): SyncedText {
    val text = remember { SyncedText(mutableStateOf(value)) }
    LaunchedEffect(value) { text.received(value) }
    return text
}

/** 枠の付いた入力欄 */
@Composable
fun SyncedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    keyboardType: KeyboardType = KeyboardType.Text,
    isPassword: Boolean = false,
    leadingIcon: (@Composable () -> Unit)? = null,
) {
    val text = rememberSyncedText(value)
    OutlinedTextField(
        value = text.value,
        onValueChange = { text.update(it, onValueChange) },
        placeholder = { Text(label) },
        singleLine = true,
        enabled = enabled,
        leadingIcon = leadingIcon,
        keyboardOptions = KeyboardOptions(keyboardType = if (isPassword) KeyboardType.Password else keyboardType),
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        modifier = modifier,
    )
}

/**
 * 登録したあとの画面。iOS 版と同じく、下のタブで画面を切り替え (タブと戻る道も AppViewModel が持つ)、
 * タブの上にはいま映っているもののミニプレーヤーを出す
 */
@Composable
private fun AppScreen(state: RegzaAndroidSnapshot, screen: RegzaAndroidScreen?, send: Send) {
    // 画面が見えている間だけ、いま映っているものを取り直す (チャンネルのタブでも、いま見ている局の印に使う)。
    // 裏に回ったらテレビに問い合わせない
    LifecycleStartEffect(Unit) {
        send(RemoteAction.startPolling())
        onStopOrDispose { send(RemoteAction.stopPolling()) }
    }
    // タブの中で開いた画面は、戻るボタンで 1 つ戻る
    BackHandler(enabled = state.isCanGoBack) { send(RegzaAndroidAction.back()) }
    val tab = state.tab
    val back = if (state.isCanGoBack) ({ send(RegzaAndroidAction.back()) }) else null
    Scaffold(
        containerColor = AppTheme.background,
        bottomBar = {
            NavigationBar(containerColor = AppTheme.surface) {
                TabItem("remote", "リモコン", { Icon(Icons.Filled.Home, contentDescription = null) }, tab, send)
                TabItem("guide", "番組表", { Icon(Icons.Filled.DateRange, contentDescription = null) }, tab, send)
                TabItem("channels", "チャンネル", { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) }, tab, send)
                TabItem("reservations", "録画予約", { RecordIcon(Modifier.size(22.dp), color = LocalContentColor.current) }, tab, send)
            }
        },
    ) { padding ->
        // ミニプレーヤーは iOS と同じく、タブの画面の上に浮かせて重ねる (画面はその下までスクロールする)
        Box(Modifier.padding(padding)) {
            CompositionLocalProvider(LocalMiniPlayerInset provides miniPlayerHeight) { TabContent(state, screen, back, send) }
            NowPlayingBar(state, send, Modifier.align(Alignment.BottomCenter))
        }
    }
    state.nowPlayingDetail.orElse(null)?.let { NowPlayingSheet(state, it, send) }
}

/** いまのタブで見えている画面 */
@Composable
private fun TabContent(state: RegzaAndroidSnapshot, screen: RegzaAndroidScreen?, back: (() -> Unit)?, send: Send) {
    Box {
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

@Composable
private fun RowScope.TabItem(
    name: String,
    label: String,
    icon: @Composable () -> Unit,
    selected: String,
    send: Send,
) {
    NavigationBarItem(
        selected = selected == name, onClick = { send(RegzaAndroidAction.selectTab(name)) },
        icon = icon, label = { Text(label) },
        // 選んでいるタブは、iOS 版と同じく強調色の文字とアイコンにする (Material の丸い地は付けない)
        colors = NavigationBarItemDefaults.colors(
            selectedIconColor = AppTheme.accent, selectedTextColor = AppTheme.accent, indicatorColor = Color.Transparent,
        ),
    )
}
