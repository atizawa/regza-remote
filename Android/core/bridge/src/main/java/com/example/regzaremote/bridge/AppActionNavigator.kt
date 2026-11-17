package com.example.regzaremote.bridge

import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.presentation.app.AppSend
import com.example.regzaremote.presentation.core.AppNavigator

/** 機能の画面が頼む画面の移り変わりを、アプリ全体の操作にして送る */
interface AppActionNavigator :
    AppNavigator,
    AppSend {
    override fun push(route: AppRoute) = invoke(AppAction.push(route))

    override fun play(channelCode: String) = invoke(AppAction.play(channelCode))

    override fun closePlayer() = invoke(AppAction.closePlayer())

    override fun showNowPlaying() = invoke(AppAction.showNowPlaying())

    override fun closeNowPlaying() = invoke(AppAction.closeNowPlaying())

    override fun showSettings() = invoke(AppAction.showSettings())

    override fun prepareRoutes() = invoke(AppAction.prepareRoutes())
}
