package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroid
import com.example.regzaremote.core.RegzaAndroidPairing
import kotlinx.coroutines.future.await
import kotlinx.coroutines.launch
import org.swift.swiftkit.core.SwiftArena
import org.swift.swiftkit.core.SwiftError

/** Swift の値の片付けはガベージコレクションに任せる */
private val arena = SwiftArena.ofAuto()

/** 試しの画面。テレビに PIN で登録し、保存した接続情報でテレビに届くかを確かめる */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // iOS 版と同じくダークにそろえる
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    RegistrationScreen()
                }
            }
        }
    }
}

@Composable
private fun RegistrationScreen() {
    val store = ConnectionStore(LocalContext.current)
    var connection by remember { mutableStateOf(store.load()) }
    var host by remember { mutableStateOf(connection?.host ?: "") }
    var pin by remember { mutableStateOf("") }
    /** テレビに PIN を表示させて、入力を待っている登録 */
    var pairing by remember { mutableStateOf<RegzaAndroidPairing?>(null) }
    var isBusy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    /** 押している間はほかのボタンを押せなくし、失敗したら説明を出す */
    fun run(action: suspend () -> Unit) = scope.launch {
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

    Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        val registered = connection
        when {
            registered != null -> {
                Text("テレビに登録済み", style = MaterialTheme.typography.titleLarge)
                Text("アドレス: ${registered.host}")
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(onClick = {
                        run {
                            val result = RegzaAndroid.regzaProbe(registered.host, registered.user, registered.password, arena).await()
                            message = when (result.status) {
                                "ok" -> "OK: 登録した接続情報で status.htm を取得できた"
                                "unauthorized" -> "NG: 認証が通らない。登録し直してください"
                                else -> "NG: ${result.status}"
                            }
                        }
                    }, enabled = !isBusy) { Text("接続を確かめる") }
                    OutlinedButton(onClick = {
                        // 登録し直すときも同じユーザー ID を使うので、テレビの登録は増えない
                        connection = null
                        message = ""
                    }, enabled = !isBusy) { Text("登録し直す") }
                }
            }

            pairing == null -> {
                Text("テレビを登録する", style = MaterialTheme.typography.titleLarge)
                OutlinedTextField(
                    value = host,
                    onValueChange = { host = it },
                    label = { Text("テレビのアドレス") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(onClick = {
                    run {
                        val session = RegzaAndroidPairing.init(host.trim(), store.pairingUserID(), arena)
                        session.start().await()
                        pin = ""
                        pairing = session
                        message = ""
                    }
                }, enabled = host.isNotBlank() && !isBusy) { Text("テレビに PIN を表示") }
            }

            else -> {
                Text("テレビに表示された PIN を入力", style = MaterialTheme.typography.titleLarge)
                OutlinedTextField(
                    value = pin,
                    onValueChange = { pin = it },
                    label = { Text("PIN") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(onClick = {
                        run {
                            val confirmed = pairing!!.confirm(pin.trim(), arena).await()
                            val saved = Connection(confirmed.host, confirmed.user, confirmed.password)
                            store.save(saved)
                            connection = saved
                            pairing = null
                            message = "登録しました"
                        }
                    }, enabled = pin.isNotBlank() && !isBusy) { Text("登録") }
                    OutlinedButton(onClick = {
                        run {
                            pairing?.cancel()?.await()
                            pairing = null
                            message = ""
                        }
                    }, enabled = !isBusy) { Text("やめる") }
                }
            }
        }
        if (message.isNotEmpty()) Text(message)
    }
}
