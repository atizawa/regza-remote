package com.example.regzaremote

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.NowPlayingItem
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidNowPlaying
import com.example.regzaremote.core.RegzaAndroidSnapshot
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * タブバーの上に出すミニプレーヤー (iOS 版の NowPlayingAccessory)。どのタブでもテレビで映っているものが分かる。
 * 押すと、いま映っているものの詳細を開く
 */
@Composable
fun NowPlayingBar(state: RegzaAndroidSnapshot, send: Send, modifier: Modifier = Modifier) {
    val nowPlaying = state.nowPlaying.orElse(null)
    val hasError = state.connectionError.isPresent
    // 文言は iOS と同じ NowPlayingItem.captionText・headlineText
    val caption = if (state.isSearchingTV || hasError) null else nowPlaying?.captionText?.orElse(null)
    val headline = when {
        state.isSearchingTV -> "テレビを探しています…"
        hasError -> "テレビに接続できません"
        else -> nowPlaying?.headlineText ?: "接続中…"
    }
    val progress = if (nowPlaying != null && nowPlaying.isHasTimeline && !hasError) nowPlaying.progress.toFloat() else null
    val key = if (nowPlaying != null && !hasError) miniPlayerKey(nowPlaying.kind.rawValue, nowPlaying.isAdvancing) else null

    Row(
        modifier
            .fillMaxWidth()
            .padding(horizontal = Design.outer, vertical = 8.dp)
            .height(miniPlayerHeight - 16.dp)
            // 下の画面から浮いて見えるよう、影を付ける
            .shadow(8.dp, RoundedCornerShape(50))
            .background(AppTheme.surface, RoundedCornerShape(50))
            .border(0.5.dp, AppTheme.separator, RoundedCornerShape(50))
            .clickable { send(RegzaAndroidAction.showNowPlaying()) }
            .padding(horizontal = Design.outer),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        ProgressRing(progress)
        Column(Modifier.weight(1f)) {
            caption?.let {
                Text(it, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, color = AppTheme.accent, maxLines = 1)
            }
            Text(headline, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (key != null) {
            TextButton(onClick = { send(RegzaAndroidAction.press(key)) }) {
                Text(if (key.rawValue == "power") "電源を入れる" else key.label, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

/** ミニプレーヤーの高さ (上下の余白を含む) */
val miniPlayerHeight = 72.dp

/** 進み具合の輪 (中にテレビの印) */
@Composable
private fun ProgressRing(progress: Float?) {
    val separator = AppTheme.separator
    val accent = AppTheme.accent
    Box(Modifier.size(30.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(30.dp)) {
            val stroke = 2.dp.toPx()
            drawCircle(separator, style = Stroke(stroke), radius = size.minDimension / 2 - stroke / 2)
            if (progress != null) {
                drawArc(
                    accent, startAngle = -90f, sweepAngle = 360f * progress, useCenter = false,
                    topLeft = androidx.compose.ui.geometry.Offset(stroke / 2, stroke / 2),
                    size = androidx.compose.ui.geometry.Size(size.width - stroke, size.height - stroke),
                    style = Stroke(stroke, cap = StrokeCap.Round),
                )
            }
        }
        Text("TV", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = accent)
    }
}

/** ミニプレーヤーを押したときの詳細 (iOS 版の NowPlayingDetailView)。録画ならシークもできる */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NowPlayingSheet(state: RegzaAndroidSnapshot, detail: RegzaAndroidNowPlaying, send: Send) {
    ModalBottomSheet(onDismissRequest = { send(RegzaAndroidAction.closeNowPlaying()) }, containerColor = AppTheme.background) {
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(horizontal = Design.outer).padding(bottom = Design.group),
            verticalArrangement = Arrangement.spacedBy(Design.group),
        ) {
            Text(detail.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.CenterHorizontally))
            NowPlayingCard(state, send)
            detail.description.orElse(null)?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 4.dp))
            }
            if (detail.isCanPowerOn) SheetButton("電源を入れる") { send(RegzaAndroidAction.powerOn()) }
            if (detail.isCanStartOver) SheetButton("この番組を最初から見る") { send(RegzaAndroidAction.startOver()) }
        }
    }
}

@Composable
private fun SheetButton(title: String, onClick: () -> Unit) {
    Box(
        Modifier
            .fillMaxWidth()
            .heightIn(min = Design.regularHeight)
            .background(AppTheme.surface, RoundedCornerShape(Design.cornerRadius))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
    }
}

/** テレビから取得した視聴状況 (iOS 版の NowPlayingCard)。録画再生中はシークできる */
@Composable
private fun NowPlayingCard(state: RegzaAndroidSnapshot, send: Send) {
    val nowPlaying = state.nowPlaying.orElse(null)
    val error = state.connectionError.orElse(null)
    Column(
        Modifier
            .fillMaxWidth()
            .background(AppTheme.surface, RoundedCornerShape(Design.cornerRadius + 4.dp))
            .padding(Design.outer),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        when {
            state.isSearchingTV -> Status("テレビが見つからないため、探しています…")
            error != null -> Status(error, isWarning = true)
            nowPlaying == null -> Status("接続中…")
            nowPlaying.kind.rawValue == "recorded" -> Playback(nowPlaying, send)
            nowPlaying.kind.rawValue == "broadcast" -> Broadcast(nowPlaying)
            else -> Status(nowPlaying.statusText.orElse(""))
        }
    }
}

@Composable
private fun Status(text: String, isWarning: Boolean = false) {
    Text(
        text, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, maxLines = 2,
        color = if (isWarning) AppTheme.orange else MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun SourceLabel(text: String) {
    Text("● $text", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = AppTheme.accent, maxLines = 1)
}

@Composable
private fun Broadcast(nowPlaying: NowPlayingItem) {
    SourceLabel(nowPlaying.channelName.ifEmpty { "放送" })
    when {
        nowPlaying.title.isNotEmpty() -> Text(nowPlaying.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, maxLines = 2)
        // 番組名が取れない機種では、ジャンルで何の番組かを示す
        nowPlaying.genre.isNotEmpty() -> Text(nowPlaying.genre, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
    }
    if (nowPlaying.isHasTimeline) {
        val start = nowPlaying.updatedAt.timeIntervalSince1970 - nowPlaying.position
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            LinearProgressIndicator(
                progress = { nowPlaying.progress.toFloat() }, modifier = Modifier.fillMaxWidth(),
                color = AppTheme.accent, trackColor = AppTheme.fill, drawStopIndicator = {},
            )
            TimeRow(clockTime(start), clockTime(start + nowPlaying.duration))
        }
    }
}

@Composable
private fun Playback(nowPlaying: NowPlayingItem, send: Send) {
    SourceLabel(if (nowPlaying.channelName.isEmpty()) "録画番組" else "録画 · ${nowPlaying.channelName}")
    Text(nowPlaying.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, maxLines = 2)
    if (nowPlaying.chapterName.isNotEmpty()) Note(nowPlaying.chapterName)
    if (nowPlaying.duration > 0) {
        // 動かしている間は手元の位置を出し、離したらテレビに送る
        var seekPosition by remember { mutableStateOf<Float?>(null) }
        val position = seekPosition ?: nowPlaying.position.toFloat()
        Slider(
            value = position, onValueChange = { seekPosition = it }, valueRange = 0f..nowPlaying.duration.toFloat(),
            onValueChangeFinished = {
                seekPosition?.let { send(RegzaAndroidAction.seek(it.toLong())) }
                seekPosition = null
            },
            colors = SliderDefaults.colors(thumbColor = AppTheme.accent, activeTrackColor = AppTheme.accent),
        )
        TimeRow(duration(position.toLong()), duration(nowPlaying.duration))
    }
}

@Composable
private fun TimeRow(leading: String, trailing: String) {
    Row(Modifier.fillMaxWidth()) {
        Note(leading)
        Spacer(Modifier.weight(1f))
        Note(trailing)
    }
}

private val clockFormat = DateTimeFormatter.ofPattern("H:mm").withZone(ZoneId.systemDefault())

private fun clockTime(seconds: Double): String = clockFormat.format(Instant.ofEpochMilli((seconds * 1000).toLong()))

/** 「1:02:03」「12:34」 (iOS 版の formattedDuration と同じ) */
private fun duration(seconds: Long): String {
    val hours = seconds / 3600
    val minutes = seconds % 3600 / 60
    val rest = seconds % 60
    return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, rest) else "%d:%02d".format(minutes, rest)
}
