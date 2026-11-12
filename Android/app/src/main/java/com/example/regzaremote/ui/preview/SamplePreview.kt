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
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.design.AppTheme

/**
 * 画面のプレビューの準備。プレビューそのものは、それぞれの画面のファイルの末尾に置く。iOS の開発用の見本・振る舞いのテストと同じ見本の返事 (RegzaSample の SampleTransport) で、
 * 共有の ViewModel を組み立てて、本物の state を画面に渡す (テレビにも録画サーバーにもつながない)。
 *
 * state は Swift の値なので、Swift のライブラリがないと作れない。
 * - 「Run Preview」(エミュレーター): アプリと同じ Android 向けの .so を使う
 * - エディタの横のプレビュー (ホストの JVM で描く): mise run prepare-android-preview で作った
 *   ホスト向けのライブラリを PreviewAppFactory が読み込む。読み込めなければ、その理由を出す
 *
 * Swift の型 (画面の道や操作) は、ライブラリを読み込んだあとでないと作れないので、setUp と content の中で作る
 *
 * @param setUp 組み立てたあとに送る操作 (一覧を読み込むなど)
 */
@Composable
fun SamplePreview(setUp: (Send) -> Unit = {}, content: @Composable (RegzaAndroidApp, Send) -> Unit) {
    MaterialTheme(colorScheme = AppTheme.colorScheme) {
        Surface(modifier = Modifier.fillMaxSize(), color = AppTheme.background) {
            val inEditor = LocalInspectionMode.current
            val sample = remember {
                runCatching {
                    PreviewAppFactory.makeApp(inEditor, setUp)
                }
            }
            sample.fold(
                onSuccess = { (app, send) -> content(app, send) },
                onFailure = { error ->
                    Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                        Text("Swift のライブラリを読み込めませんでした。「Run Preview」でエミュレーターに出してください。\n\n$error")
                    }
                },
            )
        }
    }
}

/** 見本のチャンネル (SampleTransport のチャンネル一覧の 1 局目) */
const val SAMPLE_CHANNEL = "JP-G00000001"

/** 見本の番組 (SampleTransport の番組表の、1 局目の番組) */
const val SAMPLE_PROGRAM = 1001L
