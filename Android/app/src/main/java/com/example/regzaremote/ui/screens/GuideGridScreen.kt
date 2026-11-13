package com.example.regzaremote.ui.screens

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.guideGridStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.GuideGridAction
import com.example.regzaremote.core.GuideGridState
import com.example.regzaremote.core.ProgramItem
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.Design
import com.example.regzaremote.ui.components.EmptyState
import com.example.regzaremote.ui.components.HeaderIconButton
import com.example.regzaremote.ui.components.Loading
import com.example.regzaremote.ui.components.LocalMiniPlayerInset
import com.example.regzaremote.ui.components.ProminentButton
import com.example.regzaremote.ui.components.RecordIcon
import com.example.regzaremote.ui.components.ScreenHeader
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.preview.SamplePreview

/** 新聞のテレビ欄のような番組表。横に局、縦に時刻を並べる (state と操作は GuideGridViewModel の GuideGridState・GuideGridAction) */
@Composable
fun GuideGridScreen(guide: GuideGridState, send: Send) {
    // 開いたら読み込む (予約した番組に印を付けるため、予約も読む)
    LaunchedEffect(Unit) { send(GuideGridAction.load()) }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader("番組表") {
            // 番組表を広く使うため、検索欄は置かずにボタンから別の画面で開く (iOS 版と同じ)
            if (guide.isCanSearch) {
                HeaderIconButton(Icons.Filled.Search, "番組を探す", modifier = Modifier.testTag("guide.search")) {
                    send(AppAction.push(AppRoute.search()))
                }
            }
        }
        when {
            // Mirakurun がなくてもタブは消さず、何ができるかと設定のしかたを案内する
            !guide.isHasGuide -> EmptyState(
                "番組表を使うには",
                "録画サーバー Mirakurun を使っていると、番組名つきの番組表や、番組表からの録画予約・連ドラ予約が使えます。\n" +
                    "設定画面の「録画サーバーとの連携」で Mirakurun のアドレスを設定してください。",
            ) { ProminentButton("設定を開く") { send(AppAction.showSettings()) } }

            !guide.isHasLoaded -> Loading()

            guide.columns.isEmpty() -> EmptyState("番組表を取得できません", "テレビと Mirakurun につながっているか確認してください。") {
                TextButton(onClick = { send(GuideGridAction.load()) }) { Text("もう一度試す") }
            }

            else -> {
                BandPicker(guide.bands, guide.band.orElse(null), send)
                DayPicker(guide, send)
                GuideGrid(guide, send)
            }
        }
    }
}

/** 日付の選択。今日・明日・9(月) … を横に並べ、土曜は青、日曜は赤にする (テレビ欄と同じ) */
@Composable
private fun DayPicker(guide: GuideGridState, send: Send) {
    Row(
        Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = Design.outer).padding(bottom = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        guide.days.forEachIndexed { index, day ->
            val isSelected = index.toLong() == guide.selectedDayIndex
            val color = when (day.kind.rawValue) {
                "saturday" -> AppTheme.blue
                "sunday" -> AppTheme.red
                else -> MaterialTheme.colorScheme.onSurface
            }
            Text(
                day.label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (isSelected) Color.White else color,
                modifier = Modifier
                    .background(if (isSelected) AppTheme.accent else AppTheme.fill, CircleShape)
                    .clickable { send(GuideGridAction.selectDay(day.date)) }
                    .padding(horizontal = 12.dp, vertical = 6.dp),
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

private data class GridColumn(val name: String, val cells: List<Cell>)

private fun ProgramItem.toCell() =
    Cell(id, channelCode, name, startText, start.timeIntervalSince1970, end.timeIntervalSince1970, genre.toInt(), isOnAir, isReserved)

private val columnWidth = 120.dp
private val timeColumnWidth = 28.dp
private val headerHeight = 36.dp
private val dpPerMinute = 2.4.dp

/** 縦横にスクロールする表。局名の行は横に、時刻の列は縦に、表と一緒に動かす */
@Composable
private fun GuideGrid(guide: GuideGridState, send: Send) {
    val columns = remember(guide) {
        guide.columns.map { column -> GridColumn(column.channelName, column.programs.map { it.toCell() }) }
    }
    val hours = remember(guide) { guide.hourLabels.toList() }
    val windowStart = guide.windowStart.timeIntervalSince1970
    val minutes = ((guide.windowEnd.timeIntervalSince1970 - windowStart) / 60).toInt()
    val horizontal = rememberScrollState()
    val vertical = rememberScrollState()

    Column(Modifier.fillMaxSize()) {
        // 局名の行は、表の上に重ねるので塗っておく
        Row(Modifier.background(AppTheme.surface)) {
            Box(Modifier.width(timeColumnWidth).height(headerHeight))
            Row(Modifier.horizontalScroll(horizontal)) {
                columns.forEach { column ->
                    Box(Modifier.width(columnWidth).height(headerHeight).gridLine(), contentAlignment = Alignment.Center) {
                        Text(
                            column.name,
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(horizontal = 4.dp),
                        )
                    }
                }
            }
        }
        // 表の最後がミニプレーヤーに隠れないよう、時刻の列と表の両方の下に同じ余白を足す (縦のスクロールをそろえる)
        val bottomInset = LocalMiniPlayerInset.current
        Row(Modifier.weight(1f)) {
            TimeColumn(hours, vertical, bottomInset)
            Box(Modifier.horizontalScroll(horizontal).verticalScroll(vertical).padding(bottom = bottomInset)) {
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
                                        .clickable { send(AppAction.push(AppRoute.programDetail(cell.id, cell.channelCode))) },
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
private fun TimeColumn(hours: List<String>, vertical: ScrollState, bottomInset: Dp) {
    Column(Modifier.width(timeColumnWidth).background(AppTheme.background).verticalScroll(vertical).padding(bottom = bottomInset)) {
        hours.forEach { hour ->
            Text(
                hour,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                modifier = Modifier.height(dpPerMinute * 60).width(timeColumnWidth).gridLine().padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun ProgramCell(cell: Cell, modifier: Modifier) {
    val accent = MaterialTheme.colorScheme.primary
    Row(
        modifier
            .background(AppTheme.surface)
            .background(if (cell.isOnAir) accent.copy(alpha = 0.14f) else Color.Transparent)
            .gridLine(),
    ) {
        // ジャンルは左端の細い線で示す (iOS 版と同じ)
        Box(Modifier.width(3.dp).fillMaxSize().background(genreColor(cell.genre).copy(alpha = 0.8f)))
        Column(Modifier.padding(start = 4.dp, end = 4.dp, top = 3.dp, bottom = 3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    cell.startText,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = if (cell.isOnAir) FontWeight.SemiBold else FontWeight.Normal,
                    color = if (cell.isOnAir) accent else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (cell.isReserved) RecordIcon(Modifier.size(10.dp))
            }
            Text(cell.name, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Medium)
        }
    }
}

private fun Modifier.gridLine(): Modifier = border(0.5.dp, AppTheme.separator, RoundedCornerShape(0.dp))

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

@Preview(name = "番組表")
@Composable
private fun GuideGridScreenPreview() = SamplePreview(setUp = { it(GuideGridAction.load()) }) { app, send ->
    rememberState(app) { app.guideGridStates() }?.let { GuideGridScreen(it, send) }
}
