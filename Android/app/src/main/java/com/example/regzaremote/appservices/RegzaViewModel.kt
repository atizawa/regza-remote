package com.example.regzaremote.appservices

import androidx.lifecycle.ViewModel
import com.example.regzaremote.bridge.AppSend
import com.example.regzaremote.bridge.Send
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.RegzaAndroidApp

/**
 * Swift の窓口 (RegzaAndroidApp) の入れ物。状態と操作そのものは iOS と同じ共有の ViewModel (Swift) が持ち、
 * 画面はそれぞれ自分の ViewModel の state を窓口から受け取り (<State の型 (先頭は小文字)>s)、操作を send で送る。
 * 画面の回転などで Activity が作り直されても残るので、Swift の ViewModel もここで 1 つだけ作る
 */
class RegzaViewModel(val app: RegzaAndroidApp) : ViewModel() {
    /** 画面から操作を送る先 (Swift の窓口に送る) */
    val send: Send = AppSend(app)

    override fun onCleared() {
        // アプリを閉じたら、テレビの PIN 表示も取り消し、ライブ視聴の配信も止める (待たずに送るだけ)
        send(AppAction.closeSettings())
        send(AppAction.closePlayer())
    }
}
