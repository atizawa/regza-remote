package com.example.regzaremote.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleStartEffect
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.nowPlayingStates
import com.example.regzaremote.bridge.remoteStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppState
import com.example.regzaremote.core.AppTab
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.localization.AppStrings
import com.example.regzaremote.ui.components.LocalMiniPlayerInset
import com.example.regzaremote.ui.components.RecordIcon
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.navigation.TabContent

/**
 * 登録したあとの画面。iOS 版と同じく、下のタブで画面を切り替え (タブと戻る道も AppViewModel が持つ)、
 * タブの上にはいま映っているもののミニプレーヤーを出す
 */
@Composable
fun AppScreen(app: RegzaAndroidApp, state: AppState, send: Send) {
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
                TabItem(AppTab.remote(), AppStrings.tabRemote, { Icon(Icons.Filled.Home, contentDescription = null) }, tab, send)
                TabItem(AppTab.guide(), AppStrings.tabGuide, { Icon(Icons.Filled.DateRange, contentDescription = null) }, tab, send)
                TabItem(AppTab.channels(), AppStrings.tabChannels, {
                    Icon(Icons.AutoMirrored.Filled.List, contentDescription = null)
                }, tab, send)
                TabItem(AppTab.reservations(), AppStrings.tabReservations, {
                    RecordIcon(Modifier.size(22.dp), color = LocalContentColor.current)
                }, tab, send)
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
    rememberState(app) { app.nowPlayingStates() }?.let { NowPlayingScreen(remote, it, send) }
}

@Composable
private fun RowScope.TabItem(tab: AppTab, label: String, icon: @Composable () -> Unit, selected: AppTab, send: Send) {
    NavigationBarItem(
        modifier = Modifier.testTag("tab.${tab.rawValue}"),
        // Swift の値なので、同じタブかは rawValue で比べる
        selected = selected.rawValue == tab.rawValue,
        onClick = { send(AppAction.selectTab(tab)) },
        icon = icon,
        label = { Text(label) },
        // 選んでいるタブは、iOS 版と同じく強調色の文字とアイコンにする (Material の丸い地は付けない)
        colors = NavigationBarItemDefaults.colors(
            selectedIconColor = AppTheme.accent,
            selectedTextColor = AppTheme.accent,
            indicatorColor = Color.Transparent,
        ),
    )
}
