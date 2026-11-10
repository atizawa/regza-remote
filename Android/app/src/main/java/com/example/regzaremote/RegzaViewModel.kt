package com.example.regzaremote

import android.app.Application
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.lifecycle.AndroidViewModel
import com.example.regzaremote.core.AppAction
import com.example.regzaremote.core.RegzaAndroidApp
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/**
 * Swift の窓口 (RegzaAndroidApp) の入れ物。状態と操作そのものは iOS と同じ共有の ViewModel (Swift) が持ち、
 * 画面はそれぞれ自分の ViewModel の state を窓口から受け取り (channelListStates など)、操作を send で送る。
 * 画面の回転などで Activity が作り直されても残るので、Swift の ViewModel もここで 1 つだけ作る
 */
class RegzaViewModel(application: Application) : AndroidViewModel(application) {
    /** Swift の窓口。接続情報などは、Swift が Kotlin の保存先 (AndroidStorage) を使って読み書きする */
    val app: RegzaAndroidApp = RegzaAndroidApp.init(AndroidStorage(application))

    /** 画面から操作を送る先 (Swift の窓口に送る) */
    val send: Send = AppSend(app)

    override fun onCleared() {
        // アプリを閉じたら、テレビの PIN 表示も取り消し、ライブ視聴の配信も止める (待たずに送るだけ)
        send(AppAction.closeSettings())
        send(AppAction.closePlayer())
    }
}

/** Swift の ViewModel の state を、Compose の状態として受け取る (開いていなければ null)。key が変わったら受け取り直す */
@Composable
fun <T> rememberState(key: Any?, states: () -> Flow<T?>): T? {
    val flow = remember(key) { states() }
    // エディタの横のプレビューは、受け取るのを待たずに 1 回だけ描くので、最初の state をその場で受け取っておく
    val inEditor = LocalInspectionMode.current
    val first = remember(key) { if (inEditor) runBlocking { flow.first() } else null }
    return flow.collectAsState(first).value
}
