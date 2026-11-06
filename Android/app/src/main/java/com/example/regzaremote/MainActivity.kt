package com.example.regzaremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.unit.dp
import com.example.regzaremote.core.RegzaAndroid
import com.example.regzaremote.core.RegzaAndroidProbeResult
import kotlinx.coroutines.future.await
import kotlinx.coroutines.launch
import org.swift.swiftkit.core.SwiftArena

/** Swift の値の片付けはガベージコレクションに任せる */
private val arena = SwiftArena.ofAuto()

/** 試しの画面。テレビのアドレスを入れて、Swift の RegzaCore からテレビに届くかを確かめる */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // iOS 版と同じくダークにそろえる
            MaterialTheme(colorScheme = darkColorScheme()) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    ProbeScreen()
                }
            }
        }
    }
}

@Composable
private fun ProbeScreen() {
    var host by remember { mutableStateOf("") }
    var result by remember { mutableStateOf("") }
    var isProbing by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Column(modifier = Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("テレビに届くか確かめる", style = MaterialTheme.typography.titleLarge)
        OutlinedTextField(
            value = host,
            onValueChange = { host = it },
            label = { Text("テレビのアドレス") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Button(
            onClick = {
                isProbing = true
                scope.launch {
                    result = describe(RegzaAndroid.regzaProbe(host.trim(), "", "", arena).await())
                    isProbing = false
                }
            },
            enabled = host.isNotBlank() && !isProbing,
        ) {
            Text(if (isProbing) "確かめています…" else "確かめる")
        }
        Text(result)
    }
}

private fun describe(result: RegzaAndroidProbeResult): String {
    val feature = if (result.isFound) {
        "OK: /public/feature に応答 (PIN 登録${if (result.isSupportsPIN) "に対応" else "には非対応"})"
    } else {
        "NG: /public/feature に応答なし"
    }
    val status = when (result.status) {
        "ok" -> "OK: status.htm を取得"
        "unauthorized" -> "OK: status.htm は認証を求めた (Digest のやり取りまで動いた)"
        else -> "NG: status.htm: ${result.status}"
    }
    return "$feature\n$status"
}
