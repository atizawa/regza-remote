package com.example.regzaremote.ui.components

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** ロック画面と通知の表示 (Live Updates) のオン・オフ。アプリが実装を LocalLiveUpdates で渡す (部品はアプリの仕組みを知らない) */
interface LiveUpdates {
    /** 出しているか */
    val isOn: StateFlow<Boolean>

    suspend fun setEnabled(context: Context, enabled: Boolean)
}

/** 渡されていなければ (プレビューなど)、オフのまま何もしない */
val LocalLiveUpdates = staticCompositionLocalOf<LiveUpdates> {
    object : LiveUpdates {
        override val isOn: StateFlow<Boolean> = MutableStateFlow(false)

        override suspend fun setEnabled(context: Context, enabled: Boolean) {}
    }
}
