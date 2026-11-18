package com.example.regzaremote

import android.app.Application
import android.content.res.Configuration
import com.example.regzaremote.appservices.AndroidStrings
import com.example.regzaremote.appservices.AppContainer
import com.example.regzaremote.core.RegzaAndroid
import com.example.regzaremote.liveupdate.LiveUpdateController

/**
 * アプリの起動時に、Swift の MainActor をメインスレッドで動かせるようにし (ViewModel は MainActor で動く)、
 * 共有の Swift が画面に出す文言を、いまの言語の文字列リソースにする
 */
class RegzaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        RegzaAndroid.regzaSetUpMainActor()
        AndroidStrings.install(this)
        // 通知のボタンや閉じている間の更新でプロセスが起こされたときも、Live Updates が同じ Swift の窓口を使えるようにする
        LiveUpdateController.install(AppContainer::app)
    }

    /** 端末やアプリの言語を変えられたら、共有の Swift の文言も入れ直す */
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        AndroidStrings.install(this)
    }
}
