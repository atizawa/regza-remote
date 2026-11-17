package com.example.regzaremote.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback

/**
 * trigger が変わるたびに震わせる (iOS の sensoryFeedback(_:trigger:) にあたる)。最初に描いたときは震わせない。
 * 合図は共有の state の数 (ボタンを押した回数など) を渡し、iOS と同じところで震わせる
 */
@Composable
fun SensoryFeedback(type: HapticFeedbackType, trigger: Any) {
    val haptic = LocalHapticFeedback.current
    val previous = remember { arrayOf(trigger) }
    LaunchedEffect(trigger) {
        if (previous[0] == trigger) return@LaunchedEffect
        previous[0] = trigger
        haptic.performHapticFeedback(type)
    }
}
