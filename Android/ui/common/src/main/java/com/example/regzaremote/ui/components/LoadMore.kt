package com.example.regzaremote.ui.components

import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.snapshotFlow
import kotlinx.coroutines.flow.first

/**
 * 一覧の末尾が見えたら、続きを読む操作を送る。
 * 行が組み立てられたときではなく、見えたときに送る (一覧は、見えていない行を先に組み立てることがあり、
 * 行の中で送ると、スクロールしていないのに続きを読みに行く)。
 * 行が少なく一覧が画面に収まるときは、スクロールしなくても送る (画面が埋まるまで続きを読む)
 *
 * @param itemCount いまの一覧の行の数 (末尾に足した行も含める)。一覧の並べ直しが追いつくまでは送らない
 * @param enabled 続きがあり、いま読み込める (読み込み中は false にして、二重に送らない)
 */
@Composable
fun LoadMoreWhenEndVisible(listState: LazyListState, itemCount: Int, enabled: Boolean, onLoadMore: () -> Unit) {
    val latest by rememberUpdatedState(onLoadMore)
    LaunchedEffect(listState, itemCount, enabled) {
        if (!enabled) return@LaunchedEffect
        snapshotFlow {
            val info = listState.layoutInfo
            val last = info.visibleItemsInfo.lastOrNull()?.index
            last != null && info.totalItemsCount == itemCount && last >= itemCount - 1
        }.first { it }
        latest()
    }
}
