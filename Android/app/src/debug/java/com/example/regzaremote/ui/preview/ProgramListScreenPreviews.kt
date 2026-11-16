package com.example.regzaremote.ui.preview

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.tooling.preview.Preview
import com.example.regzaremote.bridge.programListStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.ChannelListAction
import com.example.regzaremote.core.ProgramListAction
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.ProgramListScreen

// 画面のプレビュー (ファイル名の画面。debug だけ)。偽物のテレビ・録画サーバーで組み立てた本物の state を渡す。
// Swift の型 (画面の道や操作) は、FakePreview が Swift のライブラリを読み込んでから作る

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
