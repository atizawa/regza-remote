package com.example.regzaremote.ui.components

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first

/**
 * 引っ張って読み直せる一覧 (iOS の refreshable にあたる)。読み直している間の印は、画面の state の読み込み中が終わったら消す。
 * iOS の引っ張って読み直しと同じく、読み直しが始まるところで軽く震わせる (Material の部品は震わせないので、ここで震わせる)。
 * すぐに読み終わると読み込み中の state が届かないこともあるので、少し待ってから、読み込み中でなくなるのを待って止める
 *
 * @param isLoading 画面の state の読み込み中
 * @param onRefresh 読み直す操作を送る
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RefreshBox(isLoading: Boolean, onRefresh: () -> Unit, modifier: Modifier = Modifier.fillMaxSize(), content: @Composable () -> Unit) {
    val haptic = LocalHapticFeedback.current
    var isRefreshing by remember { mutableStateOf(false) }
    val latestIsLoading by rememberUpdatedState(isLoading)
    LaunchedEffect(isRefreshing) {
        if (!isRefreshing) return@LaunchedEffect
        delay(300)
        snapshotFlow { latestIsLoading }.first { !it }
        isRefreshing = false
    }
    PullToRefreshBox(
        isRefreshing = isRefreshing,
        onRefresh = {
            haptic.performHapticFeedback(HapticFeedbackType.GestureThresholdActivate)
            isRefreshing = true
            onRefresh()
        },
        modifier = modifier,
    ) { content() }
}
