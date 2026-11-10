package com.example.regzaremote

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.ProgramItem
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.ProgramDetailAction
import com.example.regzaremote.core.ProgramDetailState
import com.example.regzaremote.core.ProgramListAction
import com.example.regzaremote.core.ProgramListState
import com.example.regzaremote.core.GuideSearchAction
import com.example.regzaremote.core.GuideSearchConditionChip
import com.example.regzaremote.core.GuideSearchState
import com.example.regzaremote.core.SearchResultItem
import androidx.compose.ui.tooling.preview.Preview
import com.example.regzaremote.core.ChannelListAction
import com.example.regzaremote.core.GuideGridAction

/** 1 チャンネルの番組表 (state と操作は ProgramListViewModel の ProgramListState・ProgramListAction)。日付ごとのまとまりに分けて並べる */
@Composable
fun ProgramListScreen(list: ProgramListState, onBack: (() -> Unit)?, send: Send) {
    LaunchedEffect(list.channelCode) { send(ProgramListAction.appear()) }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader(list.channelName, onBack)
        val message = list.loadErrorMessage.orElse(null)
        // 読み込む前は nil
        val days = list.days.orElse(null)
        when {
            days != null && days.isEmpty() -> EmptyState("番組表がありません", "Mirakurun がこのチャンネルの番組表を持っていません。")
            days != null -> LazyColumn(
                contentPadding = PaddingValues(start = Design.outer, top = Design.outer, end = Design.outer, bottom = Design.outer + LocalMiniPlayerInset.current),
            ) {
                days.forEach { day ->
                    item(key = "day-${day.label}") { SectionHeader(day.label, Modifier.padding(top = 8.dp, bottom = 6.dp)) }
                    val programs = day.programs.toList()
                    itemsIndexed(programs, key = { _, program -> program.id }) { index, program ->
                        Column(Modifier.background(AppTheme.surface, sectionRowShape(index, programs.size))) {
                            ProgramRow(program, send)
                            if (index < programs.size - 1) RowDivider()
                        }
                    }
                    item(key = "space-${day.label}") { Box(Modifier.padding(bottom = Design.item)) }
                }
            }
            message != null -> EmptyState("番組表を取得できません", message) {
                TextButton(onClick = { send(ProgramListAction.reload()) }) { Text("もう一度試す") }
            }
            else -> Loading()
        }
    }
}

@Composable
private fun ProgramRow(program: ProgramItem, send: Send) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { send(AppAction.push(AppRoute.programDetail(program.id, program.channelCode))) }
            .padding(start = Design.outer, end = 8.dp, top = 10.dp, bottom = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            program.startText, style = MaterialTheme.typography.bodyMedium,
            color = if (program.isOnAir) AppTheme.accent else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(48.dp),
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(program.name, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                if (program.isReserved) ReservedBadge(compact = true)
                if (program.isOnAir) Text("放送中", style = MaterialTheme.typography.bodySmall, color = AppTheme.accent)
                program.genreName.orElse(null)?.let { Note(it) }
            }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** 番組の詳細 (state と操作は ProgramDetailViewModel の ProgramDetailState・ProgramDetailAction)。切り替えて見る・録画予約・最初から見る */
@Composable
fun ProgramDetailScreen(detail: ProgramDetailState, onBack: (() -> Unit)?, send: Send) {
    val program = detail.program
    LaunchedEffect(program.id) { send(ProgramDetailAction.appear()) }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader("番組の詳細", onBack)
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(Design.outer).padding(bottom = LocalMiniPlayerInset.current),
            verticalArrangement = Arrangement.spacedBy(Design.group),
        ) {
            DetailHeader(detail)
            DetailActions(detail, send)
            detail.message.orElse(null)?.let { Note(it) }
            // 説明と、番組内容・出演者などを見出し付きの文章で続ける
            if (program.description.isNotEmpty()) Text(program.description)
            detail.texts.forEach { item ->
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(item.title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(item.text)
                }
            }
        }
    }
}

/** 局名・番組名・時刻。番組名をいちばん大きくする */
@Composable
private fun DetailHeader(detail: ProgramDetailState) {
    val program = detail.program
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            detail.channelName + if (program.isOnAir) " · 放送中" else "",
            style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = AppTheme.accent,
        )
        Text(program.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(
            program.timeText + (program.genreName.orElse(null)?.let { " · $it" } ?: ""),
            style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (program.isOnAir) {
            val start = program.start.timeIntervalSince1970
            val end = program.end.timeIntervalSince1970
            val now = System.currentTimeMillis() / 1000.0
            LinearProgressIndicator(
                progress = { ((now - start) / (end - start)).toFloat().coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                color = AppTheme.accent, trackColor = AppTheme.fill, drawStopIndicator = {},
            )
        }
        detail.reservedText.orElse(null)?.let {
            Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                RecordIcon(Modifier.size(16.dp))
                Text(it, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = AppTheme.red)
            }
        }
    }
}

/** 主な操作。見る・切り替えは緑、録画は赤で塗る */
@Composable
private fun DetailActions(detail: ProgramDetailState, send: Send) {
    Column(verticalArrangement = Arrangement.spacedBy(Design.item)) {
        Row(horizontalArrangement = Arrangement.spacedBy(Design.item)) {
            if (detail.isCanTune) {
                ActionButton("切り替えて見る", AppTheme.accent, isBusy = detail.isTuning, enabled = !detail.isTuning,
                    icon = { Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(20.dp)) }) {
                    send(ProgramDetailAction.tune(false))
                }
            }
            if (detail.isCanReserve) ReserveMenu(detail, send)
        }
        if (detail.isCanStream) {
            Row {
                ActionButton("アプリで見る", AppTheme.surface, foreground = MaterialTheme.colorScheme.onSurface) {
                    send(AppAction.play(detail.program.channelCode))
                }
            }
        }
        if (detail.isCanStartOver) {
            Row {
                ActionButton("最初から見る", AppTheme.surface, foreground = MaterialTheme.colorScheme.onSurface, enabled = !detail.isTuning) {
                    send(ProgramDetailAction.tune(true))
                }
            }
        }
    }
}

/** 「録画予約」を押すと、この回だけか連ドラ予約かを選ぶ。予約済みならメニューから取り消す */
@Composable
private fun RowScope.ReserveMenu(detail: ProgramDetailState, send: Send) {
    // 予約・取り消しの途中
    val isReserving = detail.reserving.isPresent
    var isShowingMenu by remember { mutableStateOf(false) }
    Box(Modifier.weight(1f)) {
        Row {
            if (detail.isReserved) {
                ActionButton("予約済み", AppTheme.surface, foreground = AppTheme.red, isBusy = isReserving, enabled = !isReserving,
                    icon = { Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(20.dp)) }) { isShowingMenu = true }
            } else {
                ActionButton("録画予約", AppTheme.red, isBusy = isReserving, enabled = !isReserving,
                    icon = { RecordIcon(Modifier.size(18.dp), color = Color.White) }) { isShowingMenu = true }
            }
        }
        DropdownMenu(expanded = isShowingMenu, onDismissRequest = { isShowingMenu = false }) {
            if (detail.isReserved) {
                DropdownMenuItem(
                    text = { Text(if (detail.reservationIsSeries.orElse(false)) "連ドラ予約を取り消す" else "予約を取り消す", color = AppTheme.red) },
                    onClick = {
                        isShowingMenu = false
                        send(ProgramDetailAction.cancelReservation())
                    },
                )
            } else {
                DropdownMenuItem(text = { Text("この回だけ録画") }, onClick = {
                    isShowingMenu = false
                    send(ProgramDetailAction.reserve(false))
                })
                DropdownMenuItem(text = { Text("連ドラ予約（毎回録画）") }, onClick = {
                    isShowingMenu = false
                    send(ProgramDetailAction.reserve(true))
                })
            }
        }
    }
}

/** 塗りの操作ボタン (iOS 版の FilledActionStyle)。動いている間はアイコンの代わりに回る印を出す */
@Composable
private fun RowScope.ActionButton(
    title: String,
    color: Color,
    foreground: Color = Color.White,
    isBusy: Boolean = false,
    enabled: Boolean = true,
    icon: (@Composable () -> Unit)? = null,
    onClick: () -> Unit,
) {
    Row(
        Modifier
            .weight(1f)
            .heightIn(min = Design.regularHeight)
            .background(color, RoundedCornerShape(Design.cornerRadius))
            .clickable(enabled = enabled, onClick = onClick),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CompositionLocalProvider(LocalContentColor provides foreground) {
            if (isBusy) CircularProgressIndicator(Modifier.size(18.dp), color = foreground, strokeWidth = 2.dp) else icon?.invoke()
            Text(title, fontWeight = FontWeight.SemiBold, color = foreground)
        }
    }
}

/**
 * 番組を探す (state と操作は GuideSearchViewModel の GuideSearchState・GuideSearchAction)。
 * 打った言葉から日付・時間帯・ジャンルを読み取り、残りの言葉で全部の番組から探す
 */
@Composable
fun SearchScreen(search: GuideSearchState, onBack: (() -> Unit)?, send: Send) {
    // 開いたらすぐ打てるようにする (前に探した言葉が残っていれば結果を見せる)
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { if (search.text.isEmpty()) focus.requestFocus() }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader("番組を探す", onBack)
        SyncedTextField(
            value = search.text, onValueChange = { send(GuideSearchAction.setText(it)) },
            label = "番組名・出演者・「明日の夜のドラマ」",
            leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
            modifier = Modifier.fillMaxWidth().padding(horizontal = Design.outer).focusRequester(focus),
        )
        if (search.conditions.isNotEmpty()) {
            Column(Modifier.padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                ConditionChips(search.conditions, send)
                Text(
                    "「${search.text}」をそのまま探す", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold,
                    color = AppTheme.accent,
                    modifier = Modifier.clickable { send(GuideSearchAction.searchLiterally()) }.padding(horizontal = Design.outer, vertical = 4.dp),
                )
            }
        }
        val results = search.results
        when {
            search.isBlank -> EmptyState(
                "番組を探す",
                "1 週間分の番組から、番組名・出演者・説明で探します。\n「明日の夜のドラマ」「土曜 21時から」のように、日付・時間帯・ジャンルでも絞り込めます。",
            )
            results.isEmpty() && search.isIndexing -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    CircularProgressIndicator()
                    Note("番組を読み込んでいます")
                }
            }
            results.isEmpty() -> EmptyState("「${search.text}」に一致する結果はありません", "スペルを確認するか、新しい検索を試してください。")
            else -> LazyColumn(contentPadding = PaddingValues(bottom = LocalMiniPlayerInset.current)) {
                items(results.toList(), key = { it.program.id }) { row ->
                    SearchResultRow(row, send)
                    HorizontalDivider(Modifier.padding(start = Design.outer), thickness = 0.5.dp, color = AppTheme.separator)
                }
            }
        }
    }
}

/** 読み取った条件。押すと外す */
@Composable
private fun ConditionChips(conditions: Array<GuideSearchConditionChip>, send: Send) {
    Row(
        Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = Design.outer),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("条件", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, color = AppTheme.accent)
        conditions.forEach { chip ->
            Row(
                Modifier
                    .background(AppTheme.surface, CircleShape)
                    .clickable { send(GuideSearchAction.removeCondition(chip.condition)) }
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(chip.label, style = MaterialTheme.typography.labelMedium)
                Icon(Icons.Filled.Close, contentDescription = "${chip.label} を外す", tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(12.dp))
            }
        }
    }
}

/** 時刻順に並べ、なぜ見つかったか (「〇〇 が出演」など) を添える */
@Composable
private fun SearchResultRow(row: SearchResultItem, send: Send) {
    val program = row.program
    Column(
        Modifier
            .fillMaxWidth()
            .clickable { send(AppAction.push(AppRoute.programDetail(program.id, program.channelCode))) }
            .padding(horizontal = Design.outer, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                row.timeText, style = MaterialTheme.typography.bodySmall,
                color = if (program.isOnAir) AppTheme.accent else MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Note(row.channelName)
            if (program.isReserved) RecordIcon(Modifier.size(12.dp))
        }
        Text(program.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, maxLines = 2, overflow = TextOverflow.Ellipsis)
        row.reason.orElse(null)?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = AppTheme.accent, maxLines = 1)
        }
    }
}

// Swift の型 (AppRoute など) は、SamplePreview が Swift のライブラリを読み込んでから作る

@Preview(name = "1 局の番組表")
@Composable
private fun ProgramListScreenPreview() = SamplePreview(setUp = {
    it(ChannelListAction.appear())
    it(AppAction.push(AppRoute.channelPrograms(SampleChannel)))
    it(ProgramListAction.appear())
}) { app, send ->
    val route = remember { AppRoute.channelPrograms(SampleChannel) }
    rememberState(app) { app.programListStates(route) }?.let { ProgramListScreen(it, onBack = {}, send) }
}

@Preview(name = "番組の詳細")
@Composable
private fun ProgramDetailScreenPreview() = SamplePreview(setUp = {
    it(GuideGridAction.load())
    it(AppAction.push(AppRoute.programDetail(SampleProgram, SampleChannel)))
    it(ProgramDetailAction.appear())
}) { app, send ->
    val route = remember { AppRoute.programDetail(SampleProgram, SampleChannel) }
    rememberState(app) { app.programDetailStates(route) }?.let { ProgramDetailScreen(it, onBack = {}, send) }
}
