package com.example.regzaremote

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect

/**
 * ローカルネットワークへのアクセスの許可 (Android 17 から)。テレビも Mirakurun も同じ LAN にあり、
 * 許可がないと通信がすべて止められるので、許可されるまでは案内だけを出す (iOS の「ローカルネットワーク」の許可と同じ)。
 * 初めは許可を求め、断られたら設定から許可するよう案内する
 */
@Composable
fun LocalNetworkGate(content: @Composable () -> Unit) {
    val context = LocalContext.current
    var isGranted by remember { mutableStateOf(context.hasLocalNetworkAccess()) }
    // 一度でも求めたか (求める前は案内を出さずに、すぐ許可を求める)
    var hasRequested by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        isGranted = granted
        hasRequested = true
    }
    // 設定で許可して戻ってきたときにも、取り直す
    LifecycleResumeEffect(Unit) {
        isGranted = context.hasLocalNetworkAccess()
        onPauseOrDispose {}
    }
    LaunchedEffect(Unit) {
        if (!isGranted) launcher.launch(Manifest.permission.ACCESS_LOCAL_NETWORK)
    }

    when {
        isGranted -> content()
        hasRequested -> EmptyState(
            "ローカルネットワークへのアクセスが必要です",
            "同じ Wi-Fi のテレビを操作するため、ローカルネットワークへのアクセスを許可してください。",
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                ProminentButton("許可する") { launcher.launch(Manifest.permission.ACCESS_LOCAL_NETWORK) }
                // 2 回断ると Android は許可を求める画面を出さなくなるので、アプリの設定を開けるようにする
                TextButton(onClick = { context.openAppSettings() }) { Text("設定を開く") }
            }
        }
        else -> Loading()
    }
}

/** Android 16 までは許可が要らない */
private fun Context.hasLocalNetworkAccess(): Boolean =
    Build.VERSION.SDK_INT < 37 ||
        checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK) == PackageManager.PERMISSION_GRANTED

private fun Context.openAppSettings() {
    startActivity(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
    )
}
