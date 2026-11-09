package com.example.regzaremote

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.BroadcastBand
import com.example.regzaremote.core.ChannelItem
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidChannelList

/**
 * テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える
 * (iOS 版の ChannelListView と同じ ChannelListViewModel)
 */
@Composable
fun ChannelScreen(list: RegzaAndroidChannelList, send: Send) {
    LaunchedEffect(Unit) { send(RegzaAndroidAction.showChannels()) }
    val tuningCode = list.tuningChannelCode.orElse(null)

    Column(Modifier.fillMaxSize()) {
        ScreenHeader("チャンネル") {
            HeaderIconButton(Icons.Filled.Refresh, "読み込み直す", enabled = !list.isLoading) { send(RegzaAndroidAction.reloadChannels()) }
        }
        val message = list.loadErrorMessage.orElse(null)
        when {
            message != null -> EmptyState("チャンネルを取得できません", message) {
                TextButton(onClick = { send(RegzaAndroidAction.reloadChannels()) }) { Text("もう一度試す") }
            }
            list.rows.isEmpty() -> Loading()
            else -> {
                BandPicker(list.bands, list.band.orElse(null), send)
                val rows = list.rows.toList()
                LazyColumn(contentPadding = PaddingValues(start = Design.outer, top = Design.outer, end = Design.outer, bottom = Design.outer + LocalMiniPlayerInset.current)) {
                    list.tuneError.orElse(null)?.let { error ->
                        item { Text(error, style = MaterialTheme.typography.bodySmall, color = AppTheme.red, modifier = Modifier.padding(bottom = 8.dp)) }
                    }
                    itemsIndexed(rows, key = { _, row -> row.code }) { index, row ->
                        Column(Modifier.background(AppTheme.surface, sectionRowShape(index, rows.size))) {
                            ChannelRow(row, tuningCode, canStartOver = row.isCanStartOver, send)
                            if (index < rows.size - 1) RowDivider()
                        }
                    }
                }
            }
        }
    }
}

/** 押すとすぐ切り替わるので、切り替え以外は長押しのメニューにまとめる (iOS 版と同じ) */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ChannelRow(row: ChannelItem, tuningCode: String?, canStartOver: Boolean, send: Send) {
    var isShowingMenu by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .combinedClickable(
                    enabled = tuningCode == null,
                    onClick = { send(RegzaAndroidAction.tune(row.code)) },
                    onLongClick = { isShowingMenu = true },
                )
                .padding(start = Design.outer, end = 4.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                row.numberText, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(end = 12.dp),
            )
            Column(Modifier.weight(1f).padding(vertical = 6.dp)) {
                Text(
                    row.name,
                    // 同じ放送局のサブチャンネルは控えめに出す
                    color = if (row.isSubchannel) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
                row.programName.orElse(null)?.let {
                    Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            when {
                tuningCode == row.code -> CircularProgressIndicator(Modifier.padding(horizontal = 8.dp).size(20.dp), strokeWidth = 2.dp)
                row.isNowPlaying -> Icon(Icons.Filled.Check, contentDescription = "視聴中", tint = AppTheme.accent, modifier = Modifier.padding(horizontal = 8.dp))
            }
            if (row.isHasPrograms) {
                IconButton(onClick = { send(RegzaAndroidAction.openPrograms(row.code)) }) {
                    Icon(Icons.Filled.DateRange, contentDescription = "${row.name} の番組表", tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        DropdownMenu(expanded = isShowingMenu, onDismissRequest = { isShowingMenu = false }) {
            DropdownMenuItem(text = { Text("切り替える") }, onClick = {
                isShowingMenu = false
                send(RegzaAndroidAction.tune(row.code))
            })
            if (canStartOver) {
                DropdownMenuItem(text = { Text("最初から見る") }, onClick = {
                    isShowingMenu = false
                    send(RegzaAndroidAction.tuneFromStart(row.code))
                })
            }
            if (row.isHasPrograms) {
                DropdownMenuItem(text = { Text("番組表") }, onClick = {
                    isShowingMenu = false
                    send(RegzaAndroidAction.openPrograms(row.code))
                })
            }
        }
    }
}

/**
 * 番組表とチャンネル一覧の見出しのすぐ下に置く、放送の種類の切り替え。番組表とチャンネルのタブで同じものを選ぶ
 */
@Composable
fun BandPicker(bands: Array<BroadcastBand>, band: BroadcastBand?, send: Send) {
    if (bands.size <= 1) return
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = Design.outer, vertical = 8.dp)) {
        bands.forEachIndexed { index, item ->
            SegmentedButton(
                // Swift の値なので、同じ種類かは rawValue で比べる
                selected = item.rawValue == band?.rawValue,
                onClick = { send(RegzaAndroidAction.selectBand(item)) },
                shape = SegmentedButtonDefaults.itemShape(index, bands.size),
                // iOS の切り替えと同じく、チェックの印は付けない
                icon = {},
            ) { Text(item.label) }
        }
    }
}
