package com.example.regzaremote

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleStartEffect
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.core.RegzaNowPlaying

/**
 * リモコンの画面。並びは iOS 版と同じく、実物のリモコンの
 * 電源 → 放送の種類と数字 → 十字キー → 色ボタン → 再生 の順。
 * 手の感覚で押すので、再生中かどうかでボタンの位置は変えない (再生と一時停止は同じ場所で入れ替える)
 */
@Composable
fun RemoteScreen(model: RegzaViewModel) {
    // 画面が見えている間だけ取り直す。裏に回ったらテレビに問い合わせない
    LifecycleStartEffect(model) {
        model.startPolling()
        onStopOrDispose { model.stopPolling() }
    }
    val nowPlaying = model.nowPlaying
    val message = model.message
    val send: (RegzaKey) -> Unit = model::send

    Column(
        modifier = Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        NowPlayingCard(nowPlaying)
        if (message.isNotEmpty()) Text(message, color = MaterialTheme.colorScheme.error)

        // 電源は誤って押さないよう左端に離し、入力切替・消音と並べる
        KeyRow {
            KeyButton(Keys.power, send, Modifier.weight(1f), color = Color(0xFFC71F24))
            Spacer(Modifier.weight(1f))
            KeyButton(Keys.input, send, Modifier.weight(1f))
            KeyButton(Keys.mute, send, Modifier.weight(1f))
        }

        // 地デジ・BS・CS と 1〜12。テレビのリモコンと同じ 3 列
        KeyRow { listOf(Keys.terrestrial, Keys.bs, Keys.cs).forEach { KeyButton(it, send, Modifier.weight(1f)) } }
        Keys.numbers.chunked(3).forEach { row ->
            KeyRow { row.forEach { KeyButton(it, send, Modifier.weight(1f)) } }
        }

        // 音量・十字キー・チャンネル
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                KeyButton(Keys.volumeUp, send, Modifier.fillMaxWidth())
                KeyButton(Keys.volumeDown, send, Modifier.fillMaxWidth())
            }
            Column(Modifier.weight(1.6f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                KeyRow { Spacer(Modifier.weight(1f)); KeyButton(Keys.up, send, Modifier.weight(1f)); Spacer(Modifier.weight(1f)) }
                KeyRow {
                    KeyButton(Keys.left, send, Modifier.weight(1f))
                    KeyButton(Keys.enter, send, Modifier.weight(1f),
                        color = MaterialTheme.colorScheme.primary, contentColor = MaterialTheme.colorScheme.onPrimary,
                    )
                    KeyButton(Keys.right, send, Modifier.weight(1f))
                }
                KeyRow { Spacer(Modifier.weight(1f)); KeyButton(Keys.down, send, Modifier.weight(1f)); Spacer(Modifier.weight(1f)) }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                KeyButton(Keys.channelUp, send, Modifier.fillMaxWidth())
                KeyButton(Keys.channelDown, send, Modifier.fillMaxWidth())
            }
        }
        KeyRow { listOf(Keys.back, Keys.guide, Keys.programInfo, Keys.exit).forEach { KeyButton(it, send, Modifier.weight(1f)) } }
        KeyRow {
            KeyButton(Keys.blue, send, Modifier.weight(1f), color = Color(0xFF1E5BD8))
            KeyButton(Keys.red, send, Modifier.weight(1f), color = Color(0xFFD32F2F))
            KeyButton(Keys.green, send, Modifier.weight(1f), color = Color(0xFF2E7D32))
            KeyButton(Keys.yellow, send, Modifier.weight(1f), color = Color(0xFFF9A825))
        }

        // 録画の再生
        KeyRow {
            KeyButton(Keys.previousChapter, send, Modifier.weight(1f))
            KeyButton(Keys.skipBackward, send, Modifier.weight(1f))
            KeyButton(if (nowPlaying?.isAdvancing == true) Keys.pause else Keys.play, send, Modifier.weight(1f))
            KeyButton(Keys.skipForward, send, Modifier.weight(1f))
            KeyButton(Keys.nextChapter, send, Modifier.weight(1f))
        }
        KeyRow {
            KeyButton(Keys.rewind, send, Modifier.weight(1f))
            KeyButton(Keys.stop, send, Modifier.weight(1f))
            KeyButton(Keys.fastForward, send, Modifier.weight(1f))
            KeyButton(Keys.record, send, Modifier.weight(1f), color = Color(0xFFD32F2F))
        }
        KeyRow { listOf(Keys.recordedList, Keys.timeShift, Keys.jumpToStart).forEach { KeyButton(it, send, Modifier.weight(1f)) } }

        Spacer(Modifier.height(8.dp))
        TextButton(onClick = model::reregister) { Text("テレビを登録し直す") }
    }
}

@Composable
private fun NowPlayingCard(nowPlaying: RegzaNowPlaying?) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            // 文言は iOS のミニプレーヤーと同じ (RegzaCore の RegzaNowPlaying)
            val caption = nowPlaying?.captionText?.orElse(null)
            val headline = nowPlaying?.headlineText ?: "接続中…"
            if (caption != null) Text(caption, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
            Text(headline, style = MaterialTheme.typography.titleMedium, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (nowPlaying != null && nowPlaying.duration > 0) {
                Text("${clock(nowPlaying.position)} / ${clock(nowPlaying.duration)}", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

private fun clock(seconds: Long): String = "%d:%02d".format(seconds / 60, seconds % 60)

@Composable
private fun KeyRow(content: @Composable RowScope.() -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth(), content = content)
}

/** ボタンの文字は iOS 版と同じ RegzaKey.label */
@Composable
private fun KeyButton(
    key: RegzaKey,
    send: (RegzaKey) -> Unit,
    modifier: Modifier = Modifier,
    color: Color? = null,
    contentColor: Color = Color.White,
) {
    val label = remember(key.rawValue) { key.label }
    // 「チャンネル＋」「10秒戻し」などが切れないよう、左右の余白を詰め、入りきらなければ 2 行にする
    val padding = PaddingValues(horizontal = 4.dp, vertical = 8.dp)
    val text = @Composable {
        Text(label, maxLines = 2, textAlign = TextAlign.Center, style = MaterialTheme.typography.labelMedium)
    }
    if (color != null) {
        Button(
            onClick = { send(key) }, modifier = modifier, contentPadding = padding,
            colors = ButtonDefaults.buttonColors(containerColor = color, contentColor = contentColor),
        ) { text() }
    } else {
        FilledTonalButton(onClick = { send(key) }, modifier = modifier, contentPadding = padding) { text() }
    }
}

/** 画面で使うキー。RegzaKey は Swift の値なので、描き直すたびに作らず、ここで 1 度だけ作る */
private object Keys {
    val power = RegzaKey.power()
    val input = RegzaKey.input()
    val mute = RegzaKey.mute()
    val terrestrial = RegzaKey.terrestrial()
    val bs = RegzaKey.bs()
    val cs = RegzaKey.cs()
    val numbers = listOf(
        RegzaKey.num1(), RegzaKey.num2(), RegzaKey.num3(), RegzaKey.num4(), RegzaKey.num5(), RegzaKey.num6(),
        RegzaKey.num7(), RegzaKey.num8(), RegzaKey.num9(), RegzaKey.num10(), RegzaKey.num11(), RegzaKey.num12(),
    )
    val volumeUp = RegzaKey.volumeUp()
    val volumeDown = RegzaKey.volumeDown()
    val channelUp = RegzaKey.channelUp()
    val channelDown = RegzaKey.channelDown()
    val up = RegzaKey.up()
    val down = RegzaKey.down()
    val left = RegzaKey.left()
    val right = RegzaKey.right()
    val enter = RegzaKey.enter()
    val back = RegzaKey.back()
    val guide = RegzaKey.guide()
    val programInfo = RegzaKey.programInfo()
    val exit = RegzaKey.exit()
    val blue = RegzaKey.blue()
    val red = RegzaKey.red()
    val green = RegzaKey.green()
    val yellow = RegzaKey.yellow()
    val previousChapter = RegzaKey.previousChapter()
    val skipBackward = RegzaKey.skipBackward()
    val play = RegzaKey.play()
    val pause = RegzaKey.pause()
    val skipForward = RegzaKey.skipForward()
    val nextChapter = RegzaKey.nextChapter()
    val rewind = RegzaKey.rewind()
    val stop = RegzaKey.stop()
    val fastForward = RegzaKey.fastForward()
    val record = RegzaKey.record()
    val recordedList = RegzaKey.recordedList()
    val timeShift = RegzaKey.timeShift()
    val jumpToStart = RegzaKey.jumpToStart()
}
