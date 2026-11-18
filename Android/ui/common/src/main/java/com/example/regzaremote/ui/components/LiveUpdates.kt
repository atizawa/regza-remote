package com.example.regzaremote.ui.components

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import com.example.regzaremote.liveupdate.LiveUpdates
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * ロック画面と通知の表示 (Live Updates) のオン・オフ。組み立てが実装を渡し、共通の部品 (スイッチ) が読む。渡されていなければ (プレビューなど)、オフのまま何もしない。
 * Live Updates のモジュールは機能の画面に見せないので、ここを使えるのは共通の部品と、Live Updates を読み込む組み立てだけ
 */
val LocalLiveUpdates = staticCompositionLocalOf<LiveUpdates> {
    object : LiveUpdates {
        override val isOn: StateFlow<Boolean> = MutableStateFlow(false)

        override suspend fun setEnabled(context: Context, enabled: Boolean) {}
    }
}
