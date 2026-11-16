package com.example.regzaremote.ui.preview

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.example.regzaremote.bridge.remoteStates
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.RemoteScreen

// 画面のプレビュー (ファイル名の画面。debug だけ)。偽物のテレビ・録画サーバーで組み立てた本物の state を渡す。
// Swift の型 (画面の道や操作) は、FakePreview が Swift のライブラリを読み込んでから作る

@Preview(name = "リモコン")
@Composable
private fun RemoteScreenPreview() = FakePreview(setUp = { it(RemoteAction.refresh()) }) { app, send ->
    rememberState(app) { app.remoteStates() }?.let { RemoteScreen(it, send) }
}
