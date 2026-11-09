package com.example.regzaremote

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidScreen
import com.example.regzaremote.core.RegzaAndroidSnapshot
import kotlinx.coroutines.future.await
import kotlinx.coroutines.launch

/**
 * 画面の状態と操作の入れ物。状態と操作そのものは iOS と同じ共有の ViewModel (Swift の AppViewModel) が持つので、
 * ここは Swift の状態を Compose に渡し、画面の操作を Swift に送るだけにする。
 * 画面の回転などで Activity が作り直されても残るので、Swift の ViewModel もここで 1 つだけ作る
 */
class RegzaViewModel(application: Application) : AndroidViewModel(application) {
    /** 接続情報などは、Swift が Kotlin の保存先 (AndroidStorage) を使って読み書きする */
    private val core = RegzaAndroidApp.init(AndroidStorage(application))

    /** アプリ全体の状態 (タブ・登録の画面・接続)。Swift から最初の状態を受け取るまでは null */
    var state by mutableStateOf<RegzaAndroidSnapshot?>(null)
        private set

    /** いま見えている画面の状態。中身が変わったときだけ Swift から届く */
    var screen by mutableStateOf<RegzaAndroidScreen?>(null)
        private set

    init {
        // 状態が変わるたびに受け取って画面に渡す
        viewModelScope.launch {
            var snapshot = core.snapshot().await()
            while (true) {
                state = snapshot
                snapshot = core.nextSnapshot().await()
            }
        }
        viewModelScope.launch {
            screen = core.screen().await()
            while (true) screen = core.nextScreen().await()
        }
    }

    /** 画面から操作を送る先 (Swift の窓口に送る) */
    val send: Send = AppSend(core)

    override fun onCleared() {
        // アプリを閉じたら、テレビの PIN 表示も取り消し、ライブ視聴の配信も止める (待たずに送るだけ)
        core.send(RegzaAndroidAction.closeSetup())
        core.send(RegzaAndroidAction.closePlayer())
    }
}
