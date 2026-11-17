package com.example.regzaremote.ui.preview

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.unit.dp
import com.example.regzaremote.appservices.preview.PreviewAppFactory
import com.example.regzaremote.design.AppTheme

/**
 * 画面のプレビューの準備。プレビューそのものは、それぞれの画面のファイルの末尾に置く。振る舞いのテストと同じ偽物のテレビ・録画サーバー
 * (RegzaFakeServers) で共有の ViewModel を組み立てて、本物の state を画面に渡す (本物にはつながない)。
 *
 * state は Swift の値なので、Swift のライブラリがないと作れない。
 * - 「Run Preview」(エミュレーター): アプリと同じ Android 向けの .so を使う
 * - エディタの横のプレビュー (ホストの JVM で描く): mise run prepare-android-preview で作った
 *   ホスト向けのライブラリを、debug のソースの FakeApps が読み込む。読み込めなければ、その理由を出す
 * - 偽物は debug にだけあるので、release のビルドの種類ではプレビューを出せない (debug に切り替えるよう出す)
 *
 * Swift の型 (画面の道や操作) は、ライブラリを読み込んだあとでないと作れないので、setUp と content の中で作る。
 *
 * 画面は、その機能のプレビューが受け取るアプリ (<機能>App。送り先と state の購読) を型で選んで受け取る
 * (例: FakePreview<<機能>App> { app -> ... })。どの機能の型にもなれるものを渡すので、ほかの機能の型を読み込まずに済む
 *
 * @param setUp 組み立てたあとに送る操作 (一覧を読み込むなど)
 */
@Suppress("UNCHECKED_CAST")
@Composable
fun <App> FakePreview(setUp: (App) -> Unit = {}, content: @Composable (App) -> Unit) {
    MaterialTheme(colorScheme = AppTheme.colorScheme) {
        Surface(modifier = Modifier.fillMaxSize(), color = AppTheme.background) {
            val inEditor = LocalInspectionMode.current
            val sample = remember {
                runCatching {
                    PreviewAppFactory.makeApp(inEditor) { setUp(it as App) } as App
                }
            }
            sample.fold(
                onSuccess = { app -> content(app) },
                onFailure = { error ->
                    val message = if (error is ClassNotFoundException) {
                        "プレビューは debug のビルドの種類でだけ出せます (偽物のテレビ・録画サーバーは debug にだけ入れている)。" +
                            "Build Variants で debug を選んでください。"
                    } else {
                        "Swift のライブラリを読み込めませんでした。「Run Preview」でエミュレーターに出してください。\n\n$error"
                    }
                    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) { Text(message) }
                },
            )
        }
    }
}

/** 偽物のチャンネル一覧の 1 局目 */
const val FAKE_CHANNEL = "JP-G00000001"

/** 偽物の番組表の、1 局目の放送中の番組 */
const val FAKE_PROGRAM = 100002L
