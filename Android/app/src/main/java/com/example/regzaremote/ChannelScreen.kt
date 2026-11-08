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
import androidx.compose.material3.TextButton
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
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidChannelList
import com.example.regzaremote.core.RegzaChannel

/** テレビに登録されているチャンネルを放送の種類ごとに並べ、押すとそのチャンネルに切り替える (iOS と同じ ChannelListViewModel) */
@Composable
fun ChannelScreen(list: RegzaAndroidChannelList, send: Send) {
    LaunchedEffect(Unit) { send(RegzaAndroidAction.showChannels()) }
    val bands = list.bands
    val band = list.band.orElse(null)
    val tuningCode = list.tuningChannelCode.orElse(null)

    Column(Modifier.padding(horizontal = 16.dp)) {
        ScreenHeader("チャンネル")
        BandPicker(bands, band, send)
        list.loadErrorMessage.orElse(null)?.let { message ->
            Text(message, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(vertical = 12.dp))
            TextButton(onClick = { send(RegzaAndroidAction.reloadChannels()) }) { Text("もう一度試す") }
        }
        list.tuneError.orElse(null)?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        if (list.isLoading && list.rows.isEmpty()) {
            CircularProgressIndicator(Modifier.padding(24.dp).align(Alignment.CenterHorizontally))
        }
        LazyColumn {
            items(list.rows, key = { it.code }) { row ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = tuningCode == null) { send(RegzaAndroidAction.tune(row.code)) }
                        .padding(vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        row.numberText,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.width(56.dp),
                    )
                    Column(Modifier.weight(1f)) {
                        Text(
                            row.name,
                            // 同じ放送局のサブチャンネルは控えめに出す (iOS 版と同じ)
                            color = if (row.isSubchannel) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        row.programName.orElse(null)?.let {
                            Text(
                                it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1, overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                    when {
                        tuningCode == row.code -> CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        row.isNowPlaying -> Text("✓", color = MaterialTheme.colorScheme.primary)
                    }
                    // 番組表がある局は、その局の番組表を開ける (iOS 版と同じ)
                    if (row.isHasPrograms) {
                        TextButton(onClick = { send(RegzaAndroidAction.openPrograms(row.code)) }) { Text("番組表") }
                    }
                }
                HorizontalDivider()
            }
        }
    }
}

/** 地デジ・BS・CS の切り替え。番組表とチャンネルのタブで同じものを選ぶ (iOS 版と同じ) */
@Composable
fun BandPicker(bands: Array<RegzaChannel.Band>, band: RegzaChannel.Band?, send: Send) {
    if (bands.size <= 1) return
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
        bands.forEachIndexed { index, item ->
            SegmentedButton(
                // Swift の値なので、同じ種類かは rawValue で比べる
                selected = item.rawValue == band?.rawValue,
                onClick = { send(RegzaAndroidAction.selectBand(item)) },
                shape = SegmentedButtonDefaults.itemShape(index, bands.size),
            ) { Text(item.label) }
        }
    }
}
