package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.foundation.background
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.lifecycle.viewmodel.compose.viewModel

/** 設定を開いていれば設定の画面、そうでなければタブの画面 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // iOS 版と同じくダークに固定し、強調色を緑にする
            MaterialTheme(colorScheme = AppTheme.colorScheme) {
                Surface(modifier = Modifier.fillMaxSize(), color = AppTheme.background) {
                    // テレビは同じ LAN にあるので、ローカルネットワークへのアクセスを許可されてから画面を出す
                    LocalNetworkGate {
                        val model: RegzaViewModel = viewModel()
                        val app = model.app
                        val state = rememberState(app) { app.appStates() } ?: return@LocalNetworkGate
                        // 設定は開いている間だけ state が届く
                        val settings = rememberState(app) { app.settingsStates() }
                        if (settings != null) SettingsScreen(settings, model.send) else AppScreen(app, state, model.send)
                        // アプリで見る (ライブ視聴) は、どの画面の上にも全画面で重ねる
                        rememberState(app) { app.livePlayerStates() }?.let { LivePlayerScreen(it, model.send) }
                    }
                }
            }
        }
    }
}

/**
 * 入力欄の文字。打った文字はこの画面ですぐに出し、Swift の ViewModel には操作として送る。
 * ViewModel から別の値が来たとき (見つけたテレビを選んだときなど) だけ、その値に入れ替える
 * (送った値が遅れて戻ってきても、打っている途中の文字を巻き戻さない)
 */
class SyncedText(private val text: MutableState<String>) {
    private val sent = mutableListOf<String>()
    val value: String get() = text.value

    fun update(value: String, send: (String) -> Unit) {
        text.value = value
        sent.add(value)
        send(value)
    }

    fun received(value: String) {
        if (value in sent) {
            // 送った値が戻ってきた。最後に送った値まで戻ってきたら、覚えておく必要はない
            if (value == sent.last()) sent.clear()
        } else {
            text.value = value
        }
    }
}

@Composable
fun rememberSyncedText(value: String): SyncedText {
    val text = remember { SyncedText(mutableStateOf(value)) }
    LaunchedEffect(value) { text.received(value) }
    return text
}

/** 枠の付いた入力欄 */
@Composable
fun SyncedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    keyboardType: KeyboardType = KeyboardType.Text,
    isPassword: Boolean = false,
    leadingIcon: (@Composable () -> Unit)? = null,
) {
    val text = rememberSyncedText(value)
    OutlinedTextField(
        value = text.value,
        onValueChange = { text.update(it, onValueChange) },
        placeholder = { Text(label) },
        singleLine = true,
        enabled = enabled,
        leadingIcon = leadingIcon,
        keyboardOptions = KeyboardOptions(keyboardType = if (isPassword) KeyboardType.Password else keyboardType),
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        modifier = modifier,
    )
}
