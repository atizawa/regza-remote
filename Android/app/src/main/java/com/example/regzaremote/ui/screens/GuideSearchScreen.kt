package com.example.regzaremote.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.guideSearchStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.GuideGridAction
import com.example.regzaremote.core.GuideSearchAction
import com.example.regzaremote.core.GuideSearchConditionChip
import com.example.regzaremote.core.GuideSearchState
import com.example.regzaremote.core.SearchResultItem
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.Design
import com.example.regzaremote.ui.components.EmptyState
import com.example.regzaremote.ui.components.LocalMiniPlayerInset
import com.example.regzaremote.ui.components.Note
import com.example.regzaremote.ui.components.RecordIcon
import com.example.regzaremote.ui.components.ScreenHeader
import com.example.regzaremote.ui.components.SyncedTextField
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.preview.SamplePreview

/**
 * 番組を探す (state と操作は GuideSearchViewModel の GuideSearchState・GuideSearchAction)。
 * 打った言葉から日付・時間帯・ジャンルを読み取り、残りの言葉で全部の番組から探す
 */
@Composable
fun GuideSearchScreen(search: GuideSearchState, onBack: (() -> Unit)?, send: Send) {
    // 開いたらすぐ打てるようにする (前に探した言葉が残っていれば結果を見せる)
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { if (search.text.isEmpty()) focus.requestFocus() }
    Column(Modifier.fillMaxSize()) {
        ScreenHeader("番組を探す", onBack)
        SyncedTextField(
            value = search.text,
            onValueChange = { send(GuideSearchAction.setText(it)) },
            label = "番組名・出演者・「明日の夜のドラマ」",
            leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
            modifier = Modifier.fillMaxWidth().padding(horizontal = Design.outer).focusRequester(focus),
        )
        if (search.conditions.isNotEmpty()) {
            Column(Modifier.padding(vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                ConditionChips(search.conditions, send)
                Text(
                    "「${search.text}」をそのまま探す",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = AppTheme.accent,
                    modifier = Modifier.clickable {
                        send(GuideSearchAction.searchLiterally())
                    }.padding(horizontal = Design.outer, vertical = 4.dp),
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
                Icon(
                    Icons.Filled.Close,
                    contentDescription = "${chip.label} を外す",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(12.dp),
                )
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
                row.timeText,
                style = MaterialTheme.typography.bodySmall,
                color = if (program.isOnAir) AppTheme.accent else MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Note(row.channelName)
            if (program.isReserved) RecordIcon(Modifier.size(12.dp))
        }
        Text(
            program.name,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        row.reason.orElse(null)?.let {
            Text(it, style = MaterialTheme.typography.bodySmall, color = AppTheme.accent, maxLines = 1)
        }
    }
}

// Swift の型 (画面の道など) は、SamplePreview が Swift のライブラリを読み込んでから作る

@Preview(name = "番組を探す")
@Composable
private fun GuideSearchScreenPreview() = SamplePreview(setUp = {
    it(GuideGridAction.load())
    it(AppAction.push(AppRoute.search()))
}) { app, send ->
    val route = remember { AppRoute.search() }
    rememberState(app) { app.guideSearchStates(route) }?.let { GuideSearchScreen(it, onBack = {}, send) }
}
