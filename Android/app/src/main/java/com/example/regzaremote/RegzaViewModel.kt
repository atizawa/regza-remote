package com.example.regzaremote

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidSnapshot
import com.example.regzaremote.core.RegzaConnection
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
        saved?.host ?: "", saved?.user ?: "", saved?.password ?: "", store.pairingUserID(),
    )

    /** 画面に出す状態。Swift から最初の状態を受け取るまでは null */
    var state by mutableStateOf<RegzaAndroidSnapshot?>(null)
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
    }

    fun send(action: RegzaAndroidAction) = core.send(action)

    private fun update(snapshot: RegzaAndroidSnapshot) {
        state = snapshot
        save(snapshot.connection)
    }

    /** PIN で登録したときなど、Swift の側で接続情報が変わったら保存する */
    private fun save(connection: RegzaConnection) {
        val changed = Connection(connection.host, connection.user, connection.password)
        if (changed.host.isEmpty() || changed == saved) return
        store.save(changed)
        saved = changed
    }

    override fun onCleared() {
        // アプリを閉じたら、テレビの PIN 表示も取り消す (待たずに送るだけ)
        core.send(RegzaAndroidAction.closeSetup())
    }
}
