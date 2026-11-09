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
import androidx.compose.foundation.background
import com.example.regzaremote.core.AppRoute
import androidx.navigation3.ui.NavDisplay
import androidx.navigation3.runtime.NavEntry
import androidx.compose.runtime.key
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
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppTab
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.core.AppState
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RemoteState

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
                        val app = model.app
                        val state = rememberState(app) { app.appStates() } ?: return@LocalNetworkGate
                        // 設定は開いている間だけ state が届く
                        val settings = rememberState(app) { app.settingsStates() }
                        if (settings != null) SettingsScreen(settings, model.send) else AppScreen(app, state, model.send)
                        // アプリで見る (ライブ視聴) は、どの画面の上にも全画面で重ねる
                        rememberState(app) { app.livePlayerStates() }?.let { LivePlayerScreen(it, model.send) }
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
private fun AppScreen(app: RegzaAndroidApp, state: AppState, send: Send) {
    val remote = rememberState(app) { app.remoteStates() } ?: return
    // 画面が見えている間だけ、いま映っているものを取り直す (チャンネルのタブでも、いま見ている局の印に使う)。
    // 裏に回ったらテレビに問い合わせない
    LifecycleStartEffect(Unit) {
        send(RemoteAction.startPolling())
        onStopOrDispose { send(RemoteAction.stopPolling()) }
    }
    val tab = state.tab
    Scaffold(
        containerColor = AppTheme.background,
        bottomBar = {
            NavigationBar(containerColor = AppTheme.surface) {
                TabItem(AppTab.remote(), "リモコン", { Icon(Icons.Filled.Home, contentDescription = null) }, tab, send)
                TabItem(AppTab.guide(), "番組表", { Icon(Icons.Filled.DateRange, contentDescription = null) }, tab, send)
                TabItem(AppTab.channels(), "チャンネル", { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) }, tab, send)
                TabItem(AppTab.reservations(), "録画予約", { RecordIcon(Modifier.size(22.dp), color = LocalContentColor.current) }, tab, send)
            }
        },
    ) { padding ->
        // ミニプレーヤーは iOS と同じく、タブの画面の上に浮かせて重ねる (画面はその下までスクロールする)
        Box(Modifier.padding(padding)) {
            CompositionLocalProvider(LocalMiniPlayerInset provides miniPlayerHeight) { TabContent(app, state, remote, send) }
            NowPlayingBar(remote, send, Modifier.align(Alignment.BottomCenter))
        }
    }
    // いま映っているものの詳細は、開いている間だけ state が届く
    rememberState(app) { app.nowPlayingStates() }?.let { NowPlayingSheet(remote, it, send) }
}

/**
 * いまのタブの画面。共有の AppViewModel が持つタブの path を、Navigation 3 の back stack として渡す
 * (iOS 版が NavigationStack(path:) に渡すのと同じ)。戻るキーや戻るジェスチャーは pop を送り、path が変わると画面が切り替わる。
 * 画面はそれぞれ、自分の ViewModel の state を窓口から受け取る (戻る途中などに後ろの画面を描くときも同じ)
 */
@Composable
private fun TabContent(app: RegzaAndroidApp, state: AppState, remote: RemoteState, send: Send) {
    val tab = state.tab
    val path = state.path(tab).toList()
    // back stack の key から path の画面を引けるようにしておく (戻る途中は、閉じた画面も描くので忘れない)
    val routes = remember { HashMap<String, AppRoute>() }
    path.forEach { routes[entryKey(tab, it)] = it }
    val backStack = listOf(entryKey(tab, null)) + path.map { entryKey(tab, it) }
    // タブを切り替えたときは、画面を積んだり戻ったりするアニメーションをしない
    key(tab.rawValue) {
        NavDisplay(
            backStack = backStack,
            onBack = { send(AppAction.pop()) },
            entryProvider = { key ->
                NavEntry(key) {
                    val route = routes[key]
                    if (route == null) TabRoot(app, tab, remote, send)
                    else RouteScreen(app, key, route, back = { send(AppAction.pop()) }, send)
                }
            },
        )
    }
}

/** back stack の画面の key (タブと、path の画面の id。タブの最初の画面は空) */
private fun entryKey(tab: AppTab, route: AppRoute?) = tab.rawValue + "/" + (route?.id ?: "")

/** タブの最初の画面 */
@Composable
private fun TabRoot(app: RegzaAndroidApp, tab: AppTab, remote: RemoteState, send: Send) {
    Box(Modifier.fillMaxSize().background(AppTheme.background)) {
        when (tab.rawValue) {
            "guide" -> rememberState(tab.rawValue) { app.guideGridStates() }?.let { GuideScreen(it, send) }
            "channels" -> rememberState(tab.rawValue) { app.channelListStates() }?.let { ChannelScreen(it, send) }
            "reservations" -> rememberState(tab.rawValue) { app.reservationListStates() }?.let { ReservationsScreen(it, send) }
            else -> RemoteScreen(remote, send)
        }
    }
}

/** タブの path に積んだ画面。その画面の ViewModel の state を route で受け取る */
@Composable
private fun RouteScreen(app: RegzaAndroidApp, key: String, route: AppRoute, back: () -> Unit, send: Send) {
    Box(Modifier.fillMaxSize().background(AppTheme.background)) {
        when (route.discriminator) {
            AppRoute.Discriminator.CHANNELPROGRAMS ->
                rememberState(key) { app.programListStates(route) }?.let { ProgramListScreen(it, back, send) }
            AppRoute.Discriminator.PROGRAMDETAIL ->
                rememberState(key) { app.programDetailStates(route) }?.let { ProgramDetailScreen(it, back, send) }
            AppRoute.Discriminator.SEARCH ->
                rememberState(key) { app.guideSearchStates(route) }?.let { SearchScreen(it, back, send) }
        }
    }
}

@Composable
private fun RowScope.TabItem(
    tab: AppTab,
    label: String,
    icon: @Composable () -> Unit,
    selected: AppTab,
    send: Send,
) {
    NavigationBarItem(
        // Swift の値なので、同じタブかは rawValue で比べる
        selected = selected.rawValue == tab.rawValue, onClick = { send(AppAction.selectTab(tab)) },
        icon = icon, label = { Text(label) },
        // 選んでいるタブは、iOS 版と同じく強調色の文字とアイコンにする (Material の丸い地は付けない)
        colors = NavigationBarItemDefaults.colors(
            selectedIconColor = AppTheme.accent, selectedTextColor = AppTheme.accent, indicatorColor = Color.Transparent,
        ),
    )
}
