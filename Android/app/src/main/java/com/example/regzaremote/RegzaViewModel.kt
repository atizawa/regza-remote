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
    private val store = ConnectionStore(application)

    /** 保存してある接続情報 (変わったときだけ保存し直す) */
    private var saved: Connection? = store.load()

    private val core = RegzaAndroidApp.init(
        saved?.host ?: "", saved?.user ?: "", saved?.password ?: "", store.pairingUserID(), store.guideHost,
    )

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
                update(snapshot)
                snapshot = core.nextSnapshot().await()
            }
        }
        viewModelScope.launch {
            screen = core.screen().await()
            while (true) screen = core.nextScreen().await()
        }
    }

    fun send(action: RegzaAndroidAction) = core.send(action)

    private fun update(snapshot: RegzaAndroidSnapshot) {
        state = snapshot
        save(snapshot)
    }

    /** PIN で登録したときや設定を保存したときなど、Swift の側で変わったものを保存する */
    private fun save(snapshot: RegzaAndroidSnapshot) {
        val connection = snapshot.connection
        val changed = Connection(connection.host, connection.user, connection.password)
        if (changed.host.isNotEmpty() && changed != saved) {
            store.save(changed)
            saved = changed
        }
        if (snapshot.guideHost != store.guideHost) store.guideHost = snapshot.guideHost
    }

    override fun onCleared() {
        // アプリを閉じたら、テレビの PIN 表示も取り消す (待たずに送るだけ)
        core.send(RegzaAndroidAction.closeSetup())
    }
}
