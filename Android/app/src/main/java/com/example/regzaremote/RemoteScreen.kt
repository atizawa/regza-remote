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
import com.example.regzaremote.core.RegzaAndroid
import com.example.regzaremote.core.RegzaAndroidNowPlaying

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
    val send: (String) -> Unit = model::send

    Column(
        modifier = Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        NowPlayingCard(nowPlaying)
        if (message.isNotEmpty()) Text(message, color = MaterialTheme.colorScheme.error)

        // 電源は誤って押さないよう左端に離し、入力切替・消音と並べる
        KeyRow {
            KeyButton("power", send, Modifier.weight(1f), color = Color(0xFFC71F24))
            Spacer(Modifier.weight(1f))
            KeyButton("input", send, Modifier.weight(1f))
            KeyButton("mute", send, Modifier.weight(1f))
        }

        // 地デジ・BS・CS と 1〜12。テレビのリモコンと同じ 3 列
        KeyRow { listOf("terrestrial", "bs", "cs").forEach { KeyButton(it, send, Modifier.weight(1f)) } }
        (1..12).chunked(3).forEach { row ->
            KeyRow { row.forEach { KeyButton("num$it", send, Modifier.weight(1f)) } }
        }

        // 音量・十字キー・チャンネル
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                KeyButton("volumeUp", send, Modifier.fillMaxWidth())
                KeyButton("volumeDown", send, Modifier.fillMaxWidth())
            }
            Column(Modifier.weight(1.6f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                KeyRow { Spacer(Modifier.weight(1f)); KeyButton("up", send, Modifier.weight(1f)); Spacer(Modifier.weight(1f)) }
                KeyRow {
                    KeyButton("left", send, Modifier.weight(1f))
                    KeyButton(
                        "enter", send, Modifier.weight(1f),
                        color = MaterialTheme.colorScheme.primary, contentColor = MaterialTheme.colorScheme.onPrimary,
                    )
                    KeyButton("right", send, Modifier.weight(1f))
                }
                KeyRow { Spacer(Modifier.weight(1f)); KeyButton("down", send, Modifier.weight(1f)); Spacer(Modifier.weight(1f)) }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                KeyButton("channelUp", send, Modifier.fillMaxWidth())
                KeyButton("channelDown", send, Modifier.fillMaxWidth())
            }
        }
        KeyRow { listOf("back", "guide", "programInfo", "exit").forEach { KeyButton(it, send, Modifier.weight(1f)) } }
        KeyRow {
            KeyButton("blue", send, Modifier.weight(1f), color = Color(0xFF1E5BD8))
            KeyButton("red", send, Modifier.weight(1f), color = Color(0xFFD32F2F))
            KeyButton("green", send, Modifier.weight(1f), color = Color(0xFF2E7D32))
            KeyButton("yellow", send, Modifier.weight(1f), color = Color(0xFFF9A825))
        }

        // 録画の再生
        KeyRow {
            KeyButton("previousChapter", send, Modifier.weight(1f))
            KeyButton("skipBackward", send, Modifier.weight(1f))
            KeyButton(if (nowPlaying?.isAdvancing == true) "pause" else "play", send, Modifier.weight(1f))
            KeyButton("skipForward", send, Modifier.weight(1f))
            KeyButton("nextChapter", send, Modifier.weight(1f))
        }
        KeyRow {
            KeyButton("rewind", send, Modifier.weight(1f))
            KeyButton("stop", send, Modifier.weight(1f))
            KeyButton("fastForward", send, Modifier.weight(1f))
            KeyButton("record", send, Modifier.weight(1f), color = Color(0xFFD32F2F))
        }
        KeyRow { listOf("recordedList", "timeShift", "jumpToStart").forEach { KeyButton(it, send, Modifier.weight(1f)) } }

        Spacer(Modifier.height(8.dp))
        TextButton(onClick = model::reregister) { Text("テレビを登録し直す") }
    }
}

@Composable
private fun NowPlayingCard(nowPlaying: RegzaAndroidNowPlaying?) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            val (caption, headline) = when (nowPlaying?.kind) {
                null -> "" to "接続中…"
                // 番組名が取れないとき (Mirakurun が未設定など) は局名を大きく出し、同じ局名を上に重ねない
                "broadcast" -> if (nowPlaying.title.isEmpty()) {
                    "" to nowPlaying.channelName.ifEmpty { "放送" }
                } else {
                    nowPlaying.channelName to nowPlaying.title
                }
                "recorded" -> "録画" to nowPlaying.title
                "external" -> "" to "外部入力"
                "standby" -> "" to "待機中"
                else -> "" to "接続済み"
            }
            if (caption.isNotEmpty()) Text(caption, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
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

/** key は RegzaKey の名前。ボタンの文字は iOS 版と同じものを Swift 側から取る */
@Composable
private fun KeyButton(
    key: String,
    send: (String) -> Unit,
    modifier: Modifier = Modifier,
    color: Color? = null,
    contentColor: Color = Color.White,
) {
    val label = remember(key) { RegzaAndroid.regzaKeyLabel(key) }
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
