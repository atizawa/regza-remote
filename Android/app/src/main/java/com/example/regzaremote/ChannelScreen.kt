package com.example.regzaremote

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

/** テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える (iOS 版と同じ) */
@Composable
fun ChannelScreen(model: RegzaViewModel) {
    LaunchedEffect(model.connection) { model.loadChannels() }
    val bands = model.bands
    val band = model.band
    val nowPlayingCode = model.nowPlaying?.channelCode

    Column(Modifier.padding(horizontal = 16.dp)) {
        if (bands.size > 1) {
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
                bands.forEachIndexed { index, item ->
                    SegmentedButton(
                        // Swift の値なので、同じ種類かは rawValue で比べる
                        selected = item.rawValue == band?.rawValue,
                        onClick = { model.selectedBand = item },
                        shape = SegmentedButtonDefaults.itemShape(index, bands.size),
                    ) { Text(item.label) }
                }
            }
        }
        val message = model.connectionError ?: model.message
        if (message.isNotEmpty()) Text(message, color = MaterialTheme.colorScheme.error)
        LazyColumn {
            items(model.listedChannels, key = { it.code }) { channel ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = model.tuningChannelCode == null) { model.tune(channel) }
                        .padding(vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        channel.formattedNumber,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.width(56.dp),
                    )
                    Text(
                        channel.name,
                        // 同じ放送局のサブチャンネルは控えめに出す (iOS 版と同じ)
                        color = if (channel.isRepresentative || band?.rawValue == "cs") {
                            MaterialTheme.colorScheme.onSurface
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    when {
                        model.tuningChannelCode == channel.code -> CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        channel.code == nowPlayingCode -> Text("✓", color = MaterialTheme.colorScheme.primary)
                    }
                }
                HorizontalDivider()
            }
        }
    }
}
