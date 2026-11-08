package com.example.regzaremote

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.InputChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.ProgramItem
import com.example.regzaremote.core.RegzaAndroidProgramDetail
import com.example.regzaremote.core.RegzaAndroidProgramList
import com.example.regzaremote.core.RegzaAndroidSearch

/** 1 チャンネルの番組表 (iOS と同じ ProgramListViewModel)。日付ごとに分けて並べる */
@Composable
fun ProgramListScreen(list: RegzaAndroidProgramList, onBack: (() -> Unit)?, send: Send) {
    LaunchedEffect(list.channelName) { send(RegzaAndroidAction.showPrograms()) }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader(list.channelName, onBack)
        val message = list.loadErrorMessage.orElse(null)
        when {
            message != null -> Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("番組表を取得できません", style = MaterialTheme.typography.titleMedium)
                Note(message)
                TextButton(onClick = { send(RegzaAndroidAction.reloadPrograms()) }) { Text("もう一度試す") }
            }
            !list.isLoaded -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            list.days.isEmpty() -> Box(Modifier.padding(16.dp)) { Note("Mirakurun がこのチャンネルの番組表を持っていません。") }
            else -> LazyColumn(Modifier.padding(horizontal = 16.dp)) {
                list.days.forEach { day ->
                    item { Text(day.label, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(vertical = 8.dp)) }
                    items(day.programs.toList(), key = { it.id }) { program -> ProgramRow(program, send) }
                }
            }
        }
    }
}

@Composable
private fun ProgramRow(program: ProgramItem, send: Send) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { send(RegzaAndroidAction.openProgram(program.channelCode, program.id)) }
            .padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(program.startText, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(48.dp))
        Column(Modifier.weight(1f)) {
            Text(program.name, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (program.isOnAir) Text("放送中", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                program.genreName.orElse(null)?.let { Note(it) }
            }
        }
        if (program.isReserved) Text("● 予約", style = MaterialTheme.typography.bodySmall, color = Color.Red)
    }
    HorizontalDivider()
}

/** 番組の詳細 (iOS と同じ ProgramDetailViewModel)。切り替えて見る・最初から見る・録画予約 */
@Composable
fun ProgramDetailScreen(detail: RegzaAndroidProgramDetail, onBack: (() -> Unit)?, send: Send) {
    val program = detail.program
    LaunchedEffect(program.id) { send(RegzaAndroidAction.showDetail()) }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader("番組の詳細", onBack)
        Column(
            Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                detail.channelName + if (program.isOnAir) " · 放送中" else "",
                style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary,
            )
            Text(program.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Note(program.timeText + (program.genreName.orElse(null)?.let { " · $it" } ?: ""))
            detail.reservedText.orElse(null)?.let { Text("● $it", color = Color.Red) }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (detail.isCanTune) {
                    Button(onClick = { send(RegzaAndroidAction.tuneProgram(false)) }, enabled = !detail.isTuning) { Text("切り替えて見る") }
                }
                if (detail.isCanStartOver) {
                    OutlinedButton(onClick = { send(RegzaAndroidAction.tuneProgram(true)) }, enabled = !detail.isTuning) { Text("最初から見る") }
                }
            }
            if (detail.isReserved) {
                OutlinedButton(onClick = { send(RegzaAndroidAction.cancelProgramReservation()) }, enabled = !detail.isReserving) {
                    Text(if (detail.isSeriesReservation) "連ドラ予約を取り消す" else "予約を取り消す")
                }
            } else if (detail.isCanReserve) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(
                        onClick = { send(RegzaAndroidAction.reserve(false)) }, enabled = !detail.isReserving,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD32F2F), contentColor = Color.White),
                    ) { Text("この回だけ録画") }
                    OutlinedButton(onClick = { send(RegzaAndroidAction.reserve(true)) }, enabled = !detail.isReserving) {
                        Text("連ドラ予約")
                    }
                }
            }
            if (detail.isReserving || detail.isTuning) CircularProgressIndicator(Modifier.padding(4.dp), strokeWidth = 2.dp)
            detail.message.orElse(null)?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }

            if (program.description.isNotEmpty()) Text(program.description)
            detail.texts.forEach { item ->
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(item.title, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(item.text)
                }
            }
        }
    }
}

/**
 * 番組を探す (iOS と同じ GuideSearchViewModel)。
 * 打った言葉から日付・時間帯・ジャンルを読み取り、残りの言葉で全部の番組から探す
 */
@Composable
fun SearchScreen(search: RegzaAndroidSearch, onBack: (() -> Unit)?, send: Send) {
    Column(Modifier.fillMaxSize()) {
        ScreenHeader("番組を探す", onBack)
        SyncedTextField(
            value = search.text, onValueChange = { send(RegzaAndroidAction.setSearchText(it)) },
            label = "番組名・出演者・「明日の夜のドラマ」",
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        )
        if (search.conditions.isNotEmpty()) {
            Row(
                Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                search.conditions.forEachIndexed { index, condition ->
                    InputChip(
                        selected = false,
                        onClick = { send(RegzaAndroidAction.removeCondition(index.toLong())) },
                        label = { Text("$condition ×") },
                    )
                }
            }
            TextButton(onClick = { send(RegzaAndroidAction.searchLiterally()) }, modifier = Modifier.padding(horizontal = 4.dp)) {
                Text("「${search.text}」をそのまま探す")
            }
        }
        val results = search.results
        when {
            search.isBlank -> Box(Modifier.padding(16.dp)) {
                Note(
                    "1 週間分の番組から、番組名・出演者・説明で探します。\n" +
                        "「明日の夜のドラマ」「土曜 21時から」のように、日付・時間帯・ジャンルでも絞り込めます。",
                )
            }
            results.isEmpty() && search.isIndexing -> Row(
                Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(strokeWidth = 2.dp)
                Text("番組を読み込んでいます")
            }
            results.isEmpty() -> Text("「${search.text}」の番組は見つかりませんでした。", modifier = Modifier.padding(16.dp))
            else -> LazyColumn(Modifier.padding(horizontal = 16.dp)) {
                items(results.toList(), key = { it.program.id }) { row ->
                    val program = row.program
                    Column(
                        Modifier
                            .fillMaxWidth()
                            .clickable { send(RegzaAndroidAction.openProgram(program.channelCode, program.id)) }
                            .padding(vertical = 10.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                row.timeText, style = MaterialTheme.typography.bodySmall,
                                color = if (program.isOnAir) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Note(row.channelName)
                            if (program.isReserved) Text("●", style = MaterialTheme.typography.bodySmall, color = Color.Red)
                        }
                        Text(program.name, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        row.reason.orElse(null)?.let {
                            Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                    HorizontalDivider()
                }
            }
        }
    }
}
