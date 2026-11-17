package com.example.regzaremote.ui.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.BroadcastBand
import com.example.regzaremote.core.RemoteAction
import com.example.regzaremote.design.DesignDimensions
import com.example.regzaremote.presentation.core.CoreSend

/**
 * 番組表とチャンネル一覧の見出しのすぐ下に置く、放送の種類の切り替え。番組表とチャンネルのタブで同じものを選ぶ
 */
@Composable
fun BandPicker(bands: Array<BroadcastBand>, band: BroadcastBand?, send: CoreSend) {
    if (bands.size <= 1) return
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = DesignDimensions.spacingOuter, vertical = 8.dp)) {
        bands.forEachIndexed { index, item ->
            SegmentedButton(
                // Swift の値なので、同じ種類かは case (discriminator) で比べる
                selected = item.discriminator == band?.discriminator,
                onClick = { send(RemoteAction.selectBand(java.util.Optional.of(item))) },
                shape = SegmentedButtonDefaults.itemShape(index, bands.size),
                // iOS の切り替えと同じく、チェックの印は付けない
                icon = {},
            ) { Text(item.label) }
        }
    }
}
