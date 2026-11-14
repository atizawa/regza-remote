package com.example.regzaremote.ui.screens

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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.bridge.channelListStates
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.BroadcastBand
import com.example.regzaremote.core.ChannelItem
import com.example.regzaremote.core.ChannelListAction
import com.example.regzaremote.core.ChannelListState
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.DesignDimensions
import com.example.regzaremote.localization.AppStrings
import com.example.regzaremote.ui.components.EmptyState
import com.example.regzaremote.ui.components.HeaderIconButton
import com.example.regzaremote.ui.components.Loading
import com.example.regzaremote.ui.components.LocalMiniPlayerInset
import com.example.regzaremote.ui.components.RowDivider
import com.example.regzaremote.ui.components.ScreenHeader
import com.example.regzaremote.ui.components.rememberState
import com.example.regzaremote.ui.components.sectionRowShape
import com.example.regzaremote.ui.preview.SamplePreview

/**
 * テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える。
 * state と操作は ChannelListViewModel の ChannelListState・ChannelListAction。
 * この画面の操作 (ChannelListAction) も、番組表を開くなどアプリ全体の操作 (AppAction) も send で送る
 */
@Composable
fun ChannelListScreen(state: ChannelListState, send: Send) {
    LaunchedEffect(Unit) { send(ChannelListAction.appear()) }
    val tuningCode = state.tuningCode.orElse(null)

    Column(Modifier.fillMaxSize()) {
        ScreenHeader(AppStrings.tabChannels) {
            HeaderIconButton(Icons.Filled.Refresh, AppStrings.commonReload, enabled = !state.isLoading) { send(ChannelListAction.reload()) }
        }
        val message = state.loadErrorMessage.orElse(null)
        when {
            message != null -> EmptyState(AppStrings.channelLoadFailed, message) {
                TextButton(onClick = { send(ChannelListAction.reload()) }) { Text(AppStrings.commonRetry) }
            }

            state.rows.isEmpty() -> Loading()

            else -> {
                BandPicker(state.bands, state.band.orElse(null), send)
                val rows = state.rows.toList()
                LazyColumn(
                    contentPadding = PaddingValues(
                        start = DesignDimensions.spacingOuter,
                        top = DesignDimensions.spacingOuter,
                        end = DesignDimensions.spacingOuter,
                        bottom =
                            DesignDimensions.spacingOuter + LocalMiniPlayerInset.current,
                    ),
                ) {
                    state.tuneError.orElse(null)?.let { error ->
                        item {
                            Text(
                                error,
                                style = MaterialTheme.typography.bodySmall,
                                color = AppTheme.red,
                                modifier = Modifier.padding(bottom = 8.dp),
                            )
                        }
                    }
                    itemsIndexed(rows, key = { _, row -> row.code }) { index, row ->
                        Column(Modifier.background(AppTheme.surface, sectionRowShape(index, rows.size))) {
                            ChannelRow(row, tuningCode, canStream = state.isCanStream, send)
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
private fun ChannelRow(row: ChannelItem, tuningCode: String?, canStream: Boolean, send: Send) {
    var isShowingMenu by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier
                .fillMaxWidth()
                .combinedClickable(
                    enabled = tuningCode == null,
                    onClick = { send(ChannelListAction.tune(row.code)) },
                    onLongClick = { isShowingMenu = true },
                )
                .padding(start = DesignDimensions.spacingOuter, end = 4.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                row.numberText,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(end = 12.dp),
            )
            Column(Modifier.weight(1f).padding(vertical = 6.dp)) {
                Text(
                    row.name,
                    // 同じ放送局のサブチャンネルは控えめに出す
                    color = if (row.isSubchannel) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                row.programName.orElse(null)?.let {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            when {
                tuningCode == row.code -> CircularProgressIndicator(Modifier.padding(horizontal = 8.dp).size(20.dp), strokeWidth = 2.dp)

                row.isNowPlaying -> Icon(
                    Icons.Filled.Check,
                    contentDescription = AppStrings.channelWatching,
                    tint = AppTheme.accent,
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
            }
            if (row.isHasPrograms) {
                IconButton(onClick = { send(AppAction.push(AppRoute.channelPrograms(row.code))) }) {
                    Icon(
                        Icons.Filled.DateRange,
                        contentDescription = AppStrings.channelGuideTitle(row.name),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        DropdownMenu(expanded = isShowingMenu, onDismissRequest = { isShowingMenu = false }) {
            DropdownMenuItem(text = { Text(AppStrings.channelSwitch) }, onClick = {
                isShowingMenu = false
                send(ChannelListAction.tune(row.code))
            })
            if (canStream) {
                DropdownMenuItem(text = { Text(AppStrings.playerWatch) }, onClick = {
                    isShowingMenu = false
                    send(AppAction.play(row.code))
                })
            }
            if (row.isCanStartOver) {
                DropdownMenuItem(text = { Text(AppStrings.playerFromStart) }, onClick = {
                    isShowingMenu = false
                    send(ChannelListAction.tuneFromStart(row.code))
                })
            }
            if (row.isHasPrograms) {
                DropdownMenuItem(text = { Text(AppStrings.tabGuide) }, onClick = {
                    isShowingMenu = false
                    send(AppAction.push(AppRoute.channelPrograms(row.code)))
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
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = DesignDimensions.spacingOuter, vertical = 8.dp)) {
        bands.forEachIndexed { index, item ->
            SegmentedButton(
                // Swift の値なので、同じ種類かは rawValue で比べる
                selected = item.rawValue == band?.rawValue,
                onClick = { send(RemoteAction.selectBand(java.util.Optional.of(item))) },
                shape = SegmentedButtonDefaults.itemShape(index, bands.size),
                // iOS の切り替えと同じく、チェックの印は付けない
                icon = {},
            ) { Text(item.label) }
        }
    }
}

@Preview(name = "チャンネル一覧")
@Composable
private fun ChannelListScreenPreview() = SamplePreview(setUp = { it(ChannelListAction.appear()) }) { app, send ->
    rememberState(app) { app.channelListStates() }?.let { ChannelListScreen(it, send) }
}
