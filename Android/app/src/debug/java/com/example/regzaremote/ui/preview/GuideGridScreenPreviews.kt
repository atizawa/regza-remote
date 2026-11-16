package com.example.regzaremote.ui.preview

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.example.regzaremote.bridge.guideGridStates
import com.example.regzaremote.core.GuideGridAction
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.GuideGridScreen

// 画面のプレビュー (ファイル名の画面。debug だけ)。偽物のテレビ・録画サーバーで組み立てた本物の state を渡す。
// Swift の型 (画面の道や操作) は、FakePreview が Swift のライブラリを読み込んでから作る

@Preview(name = "番組表")
@Composable
private fun GuideGridScreenPreview() = FakePreview(setUp = { it(GuideGridAction.load()) }) { app, send ->
    rememberState(app) { app.guideGridStates() }?.let { GuideGridScreen(it, send) }
}
