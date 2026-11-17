package com.example.regzaremote.presentation.core

import com.example.regzaremote.core.AppRoute

/**
 * 機能の画面が、アプリ全体の画面の移り変わり (タブの戻る道・いま映っているものの画面・アプリで見る・設定) を頼む窓口。
 * 機能の画面はアプリ全体の操作の型を読み込まずに、送り先 (<機能>Send) のこの関数で頼む。
 * Swift の窓口に送る送り先が、アプリ全体の操作にして送る。
 * iOS の AppNavigator と違い、戻る道などの状態を読む関数は置かない (Compose では、組み立てが state を画面に渡す)
 */
interface AppNavigator {
    /** いまのタブに画面を積む */
    fun push(route: AppRoute)

    /** アプリで見る (ライブ視聴) */
    fun play(channelCode: String)

    /** アプリで見るのをやめる */
    fun closePlayer()

    /** いま映っているものの画面を出す */
    fun showNowPlaying()

    fun closeNowPlaying()

    /** 設定の画面を開く */
    fun showSettings()
}
