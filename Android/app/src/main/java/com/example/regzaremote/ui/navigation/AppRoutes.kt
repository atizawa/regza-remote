package com.example.regzaremote.ui.navigation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.navigation3.runtime.NavEntry
import androidx.navigation3.ui.NavDisplay
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.channelListStates
import com.example.regzaremote.bridge.guideGridStates
import com.example.regzaremote.bridge.guideSearchStates
import com.example.regzaremote.bridge.programDetailStates
import com.example.regzaremote.bridge.programListStates
import com.example.regzaremote.bridge.reservationListStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.AppState
import com.example.regzaremote.core.AppTab
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RemoteState
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.ChannelListScreen
import com.example.regzaremote.ui.screens.GuideGridScreen
import com.example.regzaremote.ui.screens.GuideSearchScreen
import com.example.regzaremote.ui.screens.ProgramDetailScreen
import com.example.regzaremote.ui.screens.ProgramListScreen
import com.example.regzaremote.ui.screens.RemoteScreen
import com.example.regzaremote.ui.screens.ReservationListScreen

/**
 * いまのタブの画面。共有の AppViewModel が持つタブの path を、Navigation 3 の back stack として渡す
 * (iOS 版が NavigationStack(path:) に渡すのと同じ)。戻るキーや戻るジェスチャーは pop を送り、path が変わると画面が切り替わる。
 * 画面はそれぞれ、自分の ViewModel の state を窓口から受け取る (戻る途中などに後ろの画面を描くときも同じ)
 */
@Composable
internal fun TabContent(app: RegzaAndroidApp, state: AppState, remote: RemoteState, send: Send) {
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
                    if (route == null) {
                        TabRoot(app, tab, remote, send)
                    } else {
                        RouteScreen(app, key, route, back = { send(AppAction.pop()) }, send)
                    }
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
            "guide" -> rememberState(tab.rawValue) { app.guideGridStates() }?.let { GuideGridScreen(it, send) }
            "channels" -> rememberState(tab.rawValue) { app.channelListStates() }?.let { ChannelListScreen(it, send) }
            "reservations" -> rememberState(tab.rawValue) { app.reservationListStates() }?.let { ReservationListScreen(it, send) }
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
                rememberState(key) { app.guideSearchStates(route) }?.let { GuideSearchScreen(it, back, send) }
        }
    }
}
