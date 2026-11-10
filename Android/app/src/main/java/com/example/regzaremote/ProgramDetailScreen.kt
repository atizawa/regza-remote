package com.example.regzaremote

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.GuideGridAction
import com.example.regzaremote.core.ProgramDetailAction
import com.example.regzaremote.core.ProgramDetailState

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
                    Text(
                        item.title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
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
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = AppTheme.accent,
        )
        Text(program.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(
            program.timeText + (program.genreName.orElse(null)?.let { " · $it" } ?: ""),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (program.isOnAir) {
            val start = program.start.timeIntervalSince1970
            val end = program.end.timeIntervalSince1970
            val now = System.currentTimeMillis() / 1000.0
            LinearProgressIndicator(
                progress = { ((now - start) / (end - start)).toFloat().coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                color = AppTheme.accent,
                trackColor = AppTheme.fill,
                drawStopIndicator = {},
            )
        }
        detail.reservedText.orElse(null)?.let {
            Row(
                Modifier.padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
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
                ActionButton(
                    "切り替えて見る",
                    AppTheme.accent,
                    isBusy = detail.isTuning,
                    enabled = !detail.isTuning,
                    icon = { Icon(Icons.Filled.PlayArrow, contentDescription = null, modifier = Modifier.size(20.dp)) },
                ) {
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
                ActionButton(
                    "予約済み",
                    AppTheme.surface,
                    foreground = AppTheme.red,
                    isBusy = isReserving,
                    enabled = !isReserving,
                    icon = {
                        Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(20.dp))
                    },
                ) { isShowingMenu = true }
            } else {
                ActionButton(
                    "録画予約",
                    AppTheme.red,
                    isBusy = isReserving,
                    enabled = !isReserving,
                    icon = { RecordIcon(Modifier.size(18.dp), color = Color.White) },
                ) { isShowingMenu = true }
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

// Swift の型 (AppRoute など) は、SamplePreview が Swift のライブラリを読み込んでから作る

@Preview(name = "番組の詳細")
@Composable
private fun ProgramDetailScreenPreview() = SamplePreview(setUp = {
    it(GuideGridAction.load())
    it(AppAction.push(AppRoute.programDetail(SAMPLE_PROGRAM, SAMPLE_CHANNEL)))
    it(ProgramDetailAction.appear())
}) { app, send ->
    val route = remember { AppRoute.programDetail(SAMPLE_PROGRAM, SAMPLE_CHANNEL) }
    rememberState(app) { app.programDetailStates(route) }?.let { ProgramDetailScreen(it, onBack = {}, send) }
}
