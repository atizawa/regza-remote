package com.example.regzaremote.liveupdate

import android.content.Context
import kotlinx.coroutines.flow.StateFlow

/**
 * ロック画面と通知の表示 (Live Updates) のオン・オフ。設定の画面のスイッチ (共通の部品) が使い、LiveUpdateController が実装する。
 * 画面の部品は Live Updates のモジュールを読み込んで、この型で受け取る (iOS の UICommon が LiveActivity を読み込むのと同じ向き)
 */
interface LiveUpdates {
    /** 出しているか */
    val isOn: StateFlow<Boolean>

    suspend fun setEnabled(context: Context, enabled: Boolean)
}
