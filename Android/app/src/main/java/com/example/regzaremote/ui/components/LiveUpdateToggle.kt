package com.example.regzaremote.ui.components

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.regzaremote.design.DesignDimensions
import com.example.regzaremote.liveupdate.LiveUpdateController
import com.example.regzaremote.localization.AppStrings
import kotlinx.coroutines.launch

/**
 * ロック画面と通知に表示するかのスイッチ (Live Updates。iOS の LiveActivityToggle にあたる)。
 * オンにするときに通知の権限を求め、通知や昇格がオフにされていれば、設定を開く案内を出す
 */
@Composable
fun LiveUpdateToggle(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val isOn by LiveUpdateController.isOn.collectAsStateWithLifecycle()
    // 設定から戻ってきたときに、許可が変わっていれば出し直す
    var notificationsEnabled by remember { mutableStateOf(notificationsEnabled(context)) }
    var canPromote by remember { mutableStateOf(canPromote(context)) }
    var wasDenied by remember { mutableStateOf(false) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        notificationsEnabled = notificationsEnabled(context)
        canPromote = canPromote(context)
    }
    val requestPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        notificationsEnabled = granted
        wasDenied = !granted
        if (granted) scope.launch { LiveUpdateController.setEnabled(context, true) }
    }

    fun turn(on: Boolean) {
        when {
            !on -> scope.launch { LiveUpdateController.setEnabled(context, false) }
            needsPermission(context) -> requestPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
            !notificationsEnabled(context) -> wasDenied = true
            else -> scope.launch { LiveUpdateController.setEnabled(context, true) }
        }
    }

    Column(
        modifier.fillMaxWidth().padding(horizontal = DesignDimensions.spacingOuter, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(AppStrings.liveUpdateTitle, Modifier.weight(1f))
            Switch(checked = isOn, onCheckedChange = ::turn, modifier = Modifier.testTag("liveUpdate.toggle"))
        }
        when {
            // 断られたあとや、設定で通知をオフにされているとき
            (wasDenied || isOn) && !notificationsEnabled -> Guidance(AppStrings.liveUpdateNotificationsOff) {
                context.startActivity(appSettings(context, Settings.ACTION_APP_NOTIFICATION_SETTINGS))
            }

            // 通知には出ているが、ステータスバーとロック画面の上には出せないとき (Android 16 以上)
            isOn && !canPromote && Build.VERSION.SDK_INT >= 36 -> Guidance(AppStrings.liveUpdatePromotionOff) {
                context.startActivity(appSettings(context, Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS))
            }

            else -> HelpText(AppStrings.liveUpdateHelp)
        }
    }
}

@Composable
private fun Guidance(text: String, openSettings: () -> Unit) {
    HelpText(text)
    TextButton(onClick = openSettings) { Text(AppStrings.liveUpdateOpenSettings) }
}

@Composable
private fun HelpText(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

/** Android 13 から、通知を出すにはユーザーの許可が要る */
private fun needsPermission(context: Context): Boolean = Build.VERSION.SDK_INT >= 33 &&
    context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED

private fun notificationsEnabled(context: Context): Boolean =
    context.getSystemService(NotificationManager::class.java).areNotificationsEnabled()

/** ステータスバーのチップやロック画面の上に出せるか。Android 15 以前は昇格がないので、出せるものとして扱う */
private fun canPromote(context: Context): Boolean =
    Build.VERSION.SDK_INT < 36 || context.getSystemService(NotificationManager::class.java).canPostPromotedNotifications()

private fun appSettings(context: Context, action: String): Intent =
    Intent(action).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
