package com.example.regzaremote.ui.preview

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.tooling.preview.Preview
import com.example.regzaremote.bridge.channelListStates
import com.example.regzaremote.bridge.guideGridStates
import com.example.regzaremote.bridge.guideSearchStates
import com.example.regzaremote.bridge.livePlayerStates
import com.example.regzaremote.bridge.programDetailStates
import com.example.regzaremote.bridge.programListStates
import com.example.regzaremote.bridge.remoteStates
import com.example.regzaremote.bridge.reservationListStates
import com.example.regzaremote.bridge.settingsStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.ChannelListAction
import com.example.regzaremote.core.GuideGridAction
import com.example.regzaremote.core.LivePlayerAction
import com.example.regzaremote.core.ProgramDetailAction
import com.example.regzaremote.core.ProgramListAction
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.core.ReservationListAction
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.ChannelListScreen
import com.example.regzaremote.ui.screens.GuideGridScreen
import com.example.regzaremote.ui.screens.GuideSearchScreen
import com.example.regzaremote.ui.screens.LivePlayerScreen
import com.example.regzaremote.ui.screens.ProgramDetailScreen
import com.example.regzaremote.ui.screens.ProgramListScreen
import com.example.regzaremote.ui.screens.RemoteScreen
import com.example.regzaremote.ui.screens.ReservationListScreen
import com.example.regzaremote.ui.screens.SettingsScreen

// 画面ごとのプレビュー (debug だけ)。偽物のテレビ・録画サーバーで組み立てた本物の state を渡す。
// Swift の型 (画面の道や操作) は、FakePreview が Swift のライブラリを読み込んでから作る

@Preview(name = "リモコン")
@Composable
private fun RemoteScreenPreview() = FakePreview(setUp = { it(RemoteAction.refresh()) }) { app, send ->
    rememberState(app) { app.remoteStates() }?.let { RemoteScreen(it, send) }
}

@Preview(name = "番組表")
@Composable
private fun GuideGridScreenPreview() = FakePreview(setUp = { it(GuideGridAction.load()) }) { app, send ->
    rememberState(app) { app.guideGridStates() }?.let { GuideGridScreen(it, send) }
}

@Preview(name = "番組を探す")
@Composable
private fun GuideSearchScreenPreview() = FakePreview(setUp = {
    it(GuideGridAction.load())
    it(AppAction.push(AppRoute.search()))
}) { app, send ->
    val route = remember { AppRoute.search() }
    rememberState(app) { app.guideSearchStates(route) }?.let { GuideSearchScreen(it, onBack = {}, send) }
}

@Preview(name = "番組の詳細")
@Composable
private fun ProgramDetailScreenPreview() = FakePreview(setUp = {
    it(GuideGridAction.load())
    it(AppAction.push(AppRoute.programDetail(FAKE_PROGRAM, FAKE_CHANNEL)))
    it(ProgramDetailAction.appear())
}) { app, send ->
    val route = remember { AppRoute.programDetail(FAKE_PROGRAM, FAKE_CHANNEL) }
    rememberState(app) { app.programDetailStates(route) }?.let { ProgramDetailScreen(it, onBack = {}, send) }
}

@Preview(name = "チャンネル一覧")
@Composable
private fun ChannelListScreenPreview() = FakePreview(setUp = { it(ChannelListAction.appear()) }) { app, send ->
    rememberState(app) { app.channelListStates() }?.let { ChannelListScreen(it, send) }
}

@Preview(name = "1 局の番組表")
@Composable
private fun ProgramListScreenPreview() = FakePreview(setUp = {
    it(ChannelListAction.appear())
    it(AppAction.push(AppRoute.channelPrograms(FAKE_CHANNEL)))
    it(ProgramListAction.appear())
}) { app, send ->
    val route = remember { AppRoute.channelPrograms(FAKE_CHANNEL) }
    rememberState(app) { app.programListStates(route) }?.let { ProgramListScreen(it, onBack = {}, send) }
}

@Preview(name = "ライブ視聴")
@Composable
private fun LivePlayerScreenPreview() = FakePreview(setUp = {
    it(ChannelListAction.appear())
    it(AppAction.play(FAKE_CHANNEL))
    it(LivePlayerAction.appear())
    it(LivePlayerAction.start())
}) { app, send ->
    rememberState(app) { app.livePlayerStates() }?.let { LivePlayerScreen(it, send) }
}

@Preview(name = "録画予約")
@Composable
private fun ReservationListScreenPreview() = FakePreview(setUp = { it(ReservationListAction.load()) }) { app, send ->
    rememberState(app) { app.reservationListStates() }?.let { ReservationListScreen(it, send) }
}

@Preview(name = "設定")
@Composable
private fun SettingsScreenPreview() = FakePreview(setUp = { it(AppAction.showSettings()) }) { app, send ->
    rememberState(app) { app.settingsStates() }?.let { SettingsScreen(it, send) }
}
