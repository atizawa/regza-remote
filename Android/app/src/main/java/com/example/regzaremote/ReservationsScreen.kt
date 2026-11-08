package com.example.regzaremote

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidReservation
import com.example.regzaremote.core.RegzaAndroidReservations

/** テレビの録画予約の一覧 (iOS と同じ ReservationListViewModel)。取り消しは確かめてから送る */
@Composable
fun ReservationsScreen(list: RegzaAndroidReservations, send: Send) {
    LaunchedEffect(Unit) { send(RegzaAndroidAction.showReservations()) }
    // 取り消すか確かめている予約
    var cancelling by remember { mutableStateOf<RegzaAndroidReservation?>(null) }

    Column(Modifier.fillMaxSize()) {
        ScreenHeader("録画予約") {
            TextButton(onClick = { send(RegzaAndroidAction.showReservations()) }) { Text("読み直す") }
        }
        val message = list.loadErrorMessage.orElse(null)
        list.cancelError.orElse(null)?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp))
        }
        when {
            message != null -> Box(Modifier.padding(16.dp)) { Note(message) }
            !list.isHasLoaded -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            list.scheduled.isEmpty() && list.waiting.isEmpty() -> Box(Modifier.padding(16.dp)) { Note("録画予約はありません。") }
            else -> LazyColumn(Modifier.padding(horizontal = 16.dp)) {
                if (list.scheduled.isNotEmpty()) {
                    item { Section("予定") }
                    items(list.scheduled.toList(), key = { it.id }) { ReservationRow(it) { cancelling = it } }
                }
                if (list.waiting.isNotEmpty()) {
                    item {
                        Section("次の回を待っている連ドラ予約")
                        Note("番組表に次の回が載ると、テレビが自動で予約します。日時は最後に録画した回のものです。")
                    }
                    items(list.waiting.toList(), key = { it.id }) { ReservationRow(it) { cancelling = it } }
                }
            }
        }
    }

    cancelling?.let { reservation ->
        AlertDialog(
            onDismissRequest = { cancelling = null },
            title = { Text("「${reservation.title}」の予約を取り消しますか？") },
            text = { if (reservation.repeatLabel.isPresent) Text("連ドラ予約なので、次の回以降も録画されなくなります。") },
            confirmButton = {
                TextButton(onClick = {
                    send(RegzaAndroidAction.cancelReservation(reservation.id))
                    cancelling = null
                }) { Text("取り消す", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { cancelling = null }) { Text("やめる") } },
        )
    }
}

@Composable
private fun Section(title: String) {
    Text(title, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
}

@Composable
private fun ReservationRow(reservation: RegzaAndroidReservation, onCancel: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (reservation.isRecording) Text("● 録画中", color = Color.Red, style = MaterialTheme.typography.bodySmall)
                Text(reservation.title)
            }
            Note(reservation.timeText + (reservation.repeatLabel.orElse(null)?.let { " · $it" } ?: ""))
            reservation.channelName.orElse(null)?.let { Note(it) }
        }
        TextButton(onClick = onCancel) { Text("取り消す") }
    }
    HorizontalDivider()
}
