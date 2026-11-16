package com.example.regzaremote.ui.preview

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.example.regzaremote.bridge.livePlayerStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.ChannelListAction
import com.example.regzaremote.core.LivePlayerAction
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.LivePlayerScreen

// 画面のプレビュー (ファイル名の画面。debug だけ)。偽物のテレビ・録画サーバーで組み立てた本物の state を渡す。
// Swift の型 (画面の道や操作) は、FakePreview が Swift のライブラリを読み込んでから作る

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
