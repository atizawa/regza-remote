package com.example.regzaremote.ui.components

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import com.example.regzaremote.liveupdate.LiveUpdates
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** ロック画面と通知の表示 (Live Updates) のオン・オフ。組み立てが実装を渡す。渡されていなければ (プレビューなど)、オフのまま何もしない */
val LocalLiveUpdates = staticCompositionLocalOf<LiveUpdates> {
    object : LiveUpdates {
        override val isOn: StateFlow<Boolean> = MutableStateFlow(false)

        override suspend fun setEnabled(context: Context, enabled: Boolean) {}
    }
}
