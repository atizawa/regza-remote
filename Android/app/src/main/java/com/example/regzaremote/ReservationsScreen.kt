package com.example.regzaremote

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidReservations
import com.example.regzaremote.core.ReservationItem
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first

/**
 * テレビの録画予約の一覧 (iOS 版の ReservationsView と同じ ReservationListViewModel)。
 * 引っ張ると読み直し、左へスワイプすると取り消す (取り消しは確かめてから送る)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReservationsScreen(list: RegzaAndroidReservations, send: Send) {
    LaunchedEffect(Unit) { send(RegzaAndroidAction.showReservations()) }
    // 取り消すか確かめている予約
    var cancelling by remember { mutableStateOf<ReservationItem?>(null) }
    // 引っ張って読み直している間。すぐに読み終わると読み込み中の状態が届かないこともあるので、
    // 少し待ってから、読み込み中でなくなるのを待って止める
    var isRefreshing by remember { mutableStateOf(false) }
    val isLoading by rememberUpdatedState(list.isLoading)
    LaunchedEffect(isRefreshing) {
        if (!isRefreshing) return@LaunchedEffect
        delay(300)
        snapshotFlow { isLoading }.first { !it }
        isRefreshing = false
    }

    Column(Modifier.fillMaxSize()) {
        ScreenHeader("録画予約")
        val message = list.loadErrorMessage.orElse(null)
        when {
            message != null -> EmptyState("録画予約を取得できません", message) {
                TextButton(onClick = { send(RegzaAndroidAction.showReservations()) }) { Text("もう一度試す") }
            }
            !list.isHasLoaded -> Loading()
            else -> PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    isRefreshing = true
                    send(RegzaAndroidAction.showReservations())
                },
                modifier = Modifier.fillMaxSize(),
            ) {
                if (list.scheduled.isEmpty() && list.waiting.isEmpty()) {
                    EmptyState("録画予約はありません")
                } else {
                    LazyColumn(
                        Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = Design.outer, top = Design.outer, end = Design.outer, bottom = Design.outer + LocalMiniPlayerInset.current),
                    ) {
                        list.cancelError.orElse(null)?.let { error ->
                            item { Text(error, style = MaterialTheme.typography.bodySmall, color = AppTheme.red, modifier = Modifier.padding(bottom = 8.dp)) }
                        }
                        section("予定", null, list.scheduled.toList()) { cancelling = it }
                        section(
                            "次の回を待っている連ドラ予約",
                            "番組表に次の回が載ると、テレビが自動で予約します。日時は最後に録画した回のものです。",
                            list.waiting.toList(),
                        ) { cancelling = it }
                    }
                }
            }
        }
    }

    cancelling?.let { reservation ->
        AlertDialog(
            onDismissRequest = { cancelling = null },
            title = { Text("「${reservation.title}」の予約を取り消しますか？") },
            text = { if (reservation.isSeries) Text("連ドラ予約なので、次の回以降も録画されなくなります。") },
            confirmButton = {
                TextButton(onClick = {
                    send(RegzaAndroidAction.cancelReservation(reservation.id))
                    cancelling = null
                }) { Text(if (reservation.isSeries) "連ドラ予約を取り消す" else "予約を取り消す", color = AppTheme.red) }
            },
            dismissButton = { TextButton(onClick = { cancelling = null }) { Text("やめる") } },
        )
    }
}

/** 見出しと補足の付いた、角の丸いまとまり */
private fun LazyListScope.section(header: String, footer: String?, items: List<ReservationItem>, onCancel: (ReservationItem) -> Unit) {
    if (items.isEmpty()) return
    item(key = "header-$header") { SectionHeader(header, Modifier.padding(top = 8.dp, bottom = 6.dp)) }
    itemsIndexed(items, key = { _, item -> item.id }) { index, item ->
        val shape = sectionRowShape(index, items.size)
        Column(Modifier.clip(shape)) {
            SwipeToCancel(item, onCancel)
            if (index < items.size - 1) Box(Modifier.background(AppTheme.surface)) { RowDivider() }
        }
    }
    footer?.let { item(key = "footer-$header") { Note(it, Modifier.padding(horizontal = Design.outer, vertical = 6.dp)) } }
    item(key = "space-$header") { Box(Modifier.padding(bottom = Design.group)) }
}

/** 左へスワイプすると、取り消すか確かめる */
@Composable
private fun SwipeToCancel(item: ReservationItem, onCancel: (ReservationItem) -> Unit) {
    val state = rememberSwipeToDismissBoxState()
    // 確かめる間は行を元の位置に戻しておく
    LaunchedEffect(state.currentValue) {
        if (state.currentValue == SwipeToDismissBoxValue.EndToStart) {
            onCancel(item)
            state.reset()
        }
    }
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        backgroundContent = {
            Box(Modifier.fillMaxSize().background(AppTheme.red).padding(horizontal = Design.outer), contentAlignment = Alignment.CenterEnd) {
                Text("取り消す", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
        },
    ) {
        ReservationRow(item)
    }
}

@Composable
private fun ReservationRow(item: ReservationItem) {
    Column(
        Modifier.fillMaxWidth().background(AppTheme.surface).padding(horizontal = Design.outer, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            item.title, maxLines = 2, overflow = TextOverflow.Ellipsis,
            color = if (item.isScheduled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            if (item.isRecording) {
                RecordIcon(Modifier.size(11.dp))
                Text("録画中", style = MaterialTheme.typography.bodySmall, color = AppTheme.red)
            }
            Note(item.timeText)
            item.repeatLabel.orElse(null)?.let {
                Note(it, Modifier.background(AppTheme.fill, CircleShape).padding(horizontal = 6.dp))
            }
        }
        item.channelName.orElse(null)?.let { Note(it) }
    }
}
