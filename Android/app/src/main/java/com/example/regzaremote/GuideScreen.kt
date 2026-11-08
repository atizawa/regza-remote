package com.example.regzaremote

import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidGuide
import com.example.regzaremote.core.RegzaAndroidProgram

/** 新聞のテレビ欄のような番組表。横に局、縦に時刻を並べる (iOS と同じ GuideGridViewModel) */
@Composable
fun GuideScreen(guide: RegzaAndroidGuide, send: Send) {
    // 開いたら読み込む (予約した番組に印を付けるため、予約も読む)
    LaunchedEffect(Unit) { send(RegzaAndroidAction.showGuide()) }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader("番組表") {
            // 番組表を広く使うため、検索欄は置かずにボタンから別の画面で開く (iOS 版と同じ)
            if (guide.isCanSearch) TextButton(onClick = { send(RegzaAndroidAction.openSearch()) }) { Text("番組を探す") }
        }
        when {
            !guide.isHasGuide -> Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("番組表を使うには", style = MaterialTheme.typography.titleMedium)
                Note(
                    "録画サーバー Mirakurun を使っていると、番組名つきの番組表や、番組表からの録画予約・連ドラ予約が使えます。" +
                        "設定の「番組表 (Mirakurun)」で Mirakurun のアドレスを設定してください。",
                )
                Button(onClick = { send(RegzaAndroidAction.showSetup()) }) { Text("設定を開く") }
            }
            !guide.isHasLoaded -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            guide.columns.isEmpty() -> Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("番組表を取得できません", style = MaterialTheme.typography.titleMedium)
                Note("テレビと Mirakurun につながっているか確認してください。")
                TextButton(onClick = { send(RegzaAndroidAction.showGuide()) }) { Text("もう一度試す") }
            }
            else -> {
                Box(Modifier.padding(horizontal = 16.dp)) { BandPicker(guide.bands, guide.band.orElse(null), send) }
                DayPicker(guide, send)
                GuideGrid(guide, send)
            }
        }
    }
}

/** 日付の選択。今日・明日・9(月) … を横に並べ、土曜は青、日曜は赤にする (テレビ欄と同じ) */
@Composable
private fun DayPicker(guide: RegzaAndroidGuide, send: Send) {
    Row(
        Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        guide.days.forEachIndexed { index, day ->
            val color = when (day.kind) {
                "saturday" -> Color(0xFF64B5F6)
                "sunday" -> Color(0xFFE57373)
                else -> MaterialTheme.colorScheme.onSurface
            }
            FilterChip(
                selected = day.isSelected,
                onClick = { send(RegzaAndroidAction.selectDay(index.toLong())) },
                label = { Text(day.label, color = if (day.isSelected) MaterialTheme.colorScheme.onSecondaryContainer else color) },
            )
        }
    }
}

/** 表に描く番組。Swift の値は読むたびに Swift を呼ぶので、表を描く前に Kotlin の値にしておく */
private data class Cell(
    val id: Long,
    val channelCode: String,
    val name: String,
    val startText: String,
    val start: Double,
    val end: Double,
    val genre: Int,
    val isOnAir: Boolean,
    val isReserved: Boolean,
)

private data class GuideColumn(val name: String, val cells: List<Cell>)

private fun RegzaAndroidProgram.toCell() =
    Cell(id, channelCode, name, startText, start, end, genre.toInt(), isOnAir, isReserved)

private val columnWidth = 120.dp
private val timeColumnWidth = 32.dp
private val headerHeight = 36.dp
private val dpPerMinute = 2.dp

/** 縦横にスクロールする表。局名の行は横に、時刻の列は縦に、表と一緒に動かす */
@Composable
private fun GuideGrid(guide: RegzaAndroidGuide, send: Send) {
    val columns = remember(guide) {
        guide.columns.map { column -> GuideColumn(column.channel.name, column.programs.map { it.toCell() }) }
    }
    val hours = remember(guide) { guide.hourLabels.toList() }
    val windowStart = guide.windowStart
    val minutes = ((guide.windowEnd - windowStart) / 60).toInt()
    val horizontal = rememberScrollState()
    val vertical = rememberScrollState()

    Column(Modifier.fillMaxSize()) {
        Row {
            Box(Modifier.width(timeColumnWidth).height(headerHeight))
            Row(Modifier.horizontalScroll(horizontal)) {
                columns.forEach { column ->
                    Box(Modifier.width(columnWidth).height(headerHeight).gridLine(), contentAlignment = Alignment.Center) {
                        Text(
                            column.name, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold,
                            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(horizontal = 4.dp),
                        )
                    }
                }
            }
        }
        Row(Modifier.weight(1f)) {
            TimeColumn(hours, vertical)
            Box(Modifier.horizontalScroll(horizontal).verticalScroll(vertical)) {
                Row {
                    columns.forEach { column ->
                        Box(Modifier.width(columnWidth).height(dpPerMinute * minutes)) {
                            column.cells.forEach { cell ->
                                val top = ((cell.start - windowStart) / 60).coerceIn(0.0, minutes.toDouble())
                                val bottom = ((cell.end - windowStart) / 60).coerceIn(0.0, minutes.toDouble())
                                ProgramCell(
                                    cell,
                                    Modifier
                                        .offset(y = dpPerMinute * top.toFloat())
                                        .height(dpPerMinute * (bottom - top).toFloat())
                                        .fillMaxWidth()
                                        .clickable { send(RegzaAndroidAction.openProgram(cell.channelCode, cell.id)) },
                                )
                            }
                        }
                    }
                }
                // 今の時刻の線 (今日を見ているときだけ)
                if (guide.isToday) {
                    val now = System.currentTimeMillis() / 1000.0
                    val offset = ((now - windowStart) / 60).coerceIn(0.0, minutes.toDouble())
                    Box(
                        Modifier
                            .offset(y = dpPerMinute * offset.toFloat())
                            .width(columnWidth * columns.size)
                            .height(1.dp)
                            .background(Color.Red),
                    )
                }
            }
        }
    }
}

/** 左端の時刻 (正時ごと) */
@Composable
private fun TimeColumn(hours: List<String>, vertical: ScrollState) {
    Column(Modifier.width(timeColumnWidth).verticalScroll(vertical)) {
        hours.forEach { hour ->
            Text(
                hour,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.height(dpPerMinute * 60).width(timeColumnWidth).gridLine().padding(top = 2.dp, start = 4.dp),
            )
        }
    }
}

@Composable
private fun ProgramCell(cell: Cell, modifier: Modifier) {
    val accent = MaterialTheme.colorScheme.primary
    Row(
        modifier
            .background(if (cell.isOnAir) accent.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surfaceContainer)
            .gridLine(),
    ) {
        // ジャンルは左端の細い線で示す (iOS 版と同じ)
        Box(Modifier.width(3.dp).fillMaxSize().background(genreColor(cell.genre).copy(alpha = 0.8f)))
        Column(Modifier.padding(horizontal = 4.dp, vertical = 2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    cell.startText, style = MaterialTheme.typography.labelSmall,
                    color = if (cell.isOnAir) accent else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (cell.isReserved) Text("●", style = MaterialTheme.typography.labelSmall, color = Color.Red)
            }
            Text(cell.name, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Medium)
        }
    }
}

private fun Modifier.gridLine(): Modifier = border(0.5.dp, Color(0x33FFFFFF), RoundedCornerShape(0.dp))

/** ジャンル (ARIB の大分類) ごとの色 (iOS 版と同じ並び) */
private fun genreColor(genre: Int): Color = when (genre) {
    0 -> Color(0xFF2196F3)
    1 -> Color(0xFF4CAF50)
    2 -> Color(0xFF009688)
    3 -> Color(0xFFE91E63)
    4 -> Color(0xFF9C27B0)
    5 -> Color(0xFFFF9800)
    6 -> Color(0xFFF44336)
    7 -> Color(0xFFFFEB3B)
    8 -> Color(0xFF795548)
    9 -> Color(0xFF3F51B5)
    10 -> Color(0xFF26A69A)
    else -> Color.Gray
}
