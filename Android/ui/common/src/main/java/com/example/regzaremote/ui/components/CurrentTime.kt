package com.example.regzaremote.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import kotlinx.coroutines.delay

/** 今の時刻 (1970 年からの秒) を、決めた間隔で読み直して返す (iOS の TimelineView に当たる)。読み直すたびに描き直す。 */
@Composable
fun rememberCurrentTime(intervalSeconds: Long): Double {
    val now by produceState(currentSeconds(), intervalSeconds) {
        while (true) {
            delay(intervalSeconds * 1_000)
            value = currentSeconds()
        }
    }
    return now
}

private fun currentSeconds(): Double = System.currentTimeMillis() / 1_000.0
