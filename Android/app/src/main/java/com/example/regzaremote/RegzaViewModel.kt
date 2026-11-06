package com.example.regzaremote

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.regzaremote.core.RegzaAndroidPairing
import com.example.regzaremote.core.RegzaAndroidRemote
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.core.RegzaNowPlaying
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.future.await
import kotlinx.coroutines.launch
import org.swift.swiftkit.core.SwiftError

/**
 * アプリの状態 (iOS 版の RemoteViewModel に当たる)。
 * 画面の回転などで Activity が作り直されても残るので、テレビとのやり取りの途中の状態はここに持つ
 */
class RegzaViewModel(application: Application) : AndroidViewModel(application) {
    private val store = ConnectionStore(application)

    /** テレビに登録した接続情報。未登録なら null */
    var connection by mutableStateOf(store.load())
        private set

    /**
     * テレビのリモコン。切り替えの最中に play/status を問い合わせないしくみが中で待つ時間を覚えているので、
     * 作り直すと効かなくなる。接続情報が変わるまで同じものを使う
     */
    private var remote: RegzaAndroidRemote? = connection?.let(::makeRemote)

    var nowPlaying by mutableStateOf<RegzaNowPlaying?>(null)
        private set

    /** テレビに PIN を表示させて、入力を待っている登録 (テレビから受け取った暗号化パスワードを持っている) */
    var pairing by mutableStateOf<RegzaAndroidPairing?>(null)
        private set

    /** テレビとのやり取りの最中 (ほかのボタンを押せなくする) */
    var isBusy by mutableStateOf(false)
        private set

    /** 画面に出す説明 (失敗したときなど) */
    var message by mutableStateOf("")
        private set

    private var polling: Job? = null

    // MARK: PIN 登録

    fun startPairing(host: String) = run {
        val session = RegzaAndroidPairing.init(host, store.pairingUserID())
        session.start().await()
        pairing = session
        message = ""
    }

    fun confirmPairing(pin: String) = run {
        val confirmed = pairing?.confirm(pin)?.await() ?: return@run
        val saved = Connection(confirmed.host, confirmed.user, confirmed.password)
        store.save(saved)
        pairing = null
        connect(saved)
        message = "登録しました"
    }

    fun cancelPairing() = run {
        pairing?.cancel()?.await()
        pairing = null
        message = ""
    }

    /** 登録の画面に戻る。登録し直すときも同じユーザー ID を使うので、テレビの登録は増えない */
    fun reregister() {
        stopPolling()
        connection = null
        remote = null
        nowPlaying = null
        message = ""
    }

    // MARK: リモコン

    fun send(key: RegzaKey) {
        val remote = remote ?: return
        viewModelScope.launch {
            try {
                remote.send(key).await()
                message = ""
            } catch (e: SwiftError) {
                message = e.message ?: "送れませんでした"
            }
        }
    }

    /** 画面が見えている間だけ、iOS 版と同じく 2 秒ごとに取り直す (裏に回ったら stopPolling) */
    fun startPolling() {
        val remote = remote ?: return
        if (polling != null) return
        polling = viewModelScope.launch {
            while (true) {
                try {
                    nowPlaying = remote.refresh().await()
                } catch (e: SwiftError) {
                    nowPlaying = null
                    message = e.message ?: "テレビに接続できません"
                }
                delay(2_000)
            }
        }
    }

    fun stopPolling() {
        polling?.cancel()
        polling = null
    }

    override fun onCleared() {
        // アプリを閉じたら、テレビの PIN 表示も取り消す (待たずに送るだけ)
        pairing?.cancel()
    }

    private fun connect(connection: Connection) {
        this.connection = connection
        remote = makeRemote(connection)
    }

    private fun makeRemote(connection: Connection) =
        RegzaAndroidRemote.init(connection.host, connection.user, connection.password)

    /** 押している間はほかのボタンを押せなくし、失敗したら説明を出す */
    private fun run(action: suspend () -> Unit) {
        viewModelScope.launch {
            isBusy = true
            try {
                action()
            } catch (e: SwiftError) {
                // Swift の RegzaAndroidError の説明がそのままメッセージになる
                message = e.message ?: "不明なエラー"
            } finally {
                isBusy = false
            }
        }
    }
}
