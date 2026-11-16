package com.example.regzaremote.ui.preview

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.tooling.preview.Preview
import com.example.regzaremote.bridge.programDetailStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.GuideGridAction
import com.example.regzaremote.core.ProgramDetailAction
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.screens.ProgramDetailScreen

// 画面のプレビュー (ファイル名の画面。debug だけ)。偽物のテレビ・録画サーバーで組み立てた本物の state を渡す。
// Swift の型 (画面の道や操作) は、FakePreview が Swift のライブラリを読み込んでから作る

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
