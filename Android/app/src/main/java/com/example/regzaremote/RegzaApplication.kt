package com.example.regzaremote

import android.app.Application
import com.example.regzaremote.core.RegzaAndroid

/** アプリの起動時に、Swift の MainActor をメインスレッドで動かせるようにする (ViewModel は MainActor で動く) */
class RegzaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        RegzaAndroid.regzaSetUpMainActor()
    }
}
