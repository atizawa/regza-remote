package com.example.regzaremote.systemactions

import android.content.Context
import android.widget.Toast
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.localization.R as StringsR
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Glanceが保持する非同期の実行期間内で、通信の完了まで待つ。 */
class SendRemoteKeyAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val name = parameters[KEY] ?: return
        val key = RegzaKey.`init`(name).orElse(null) ?: return
        val error = try {
            RemoteControlService.make(context).send(key)
        } catch (error: CancellationException) {
            throw error
        } catch (_: Exception) {
            context.getString(StringsR.string.widget_send_failed)
        }
        if (error != null) {
            withContext(Dispatchers.Main) {
                Toast.makeText(context, error, Toast.LENGTH_LONG).show()
            }
        }
    }

    companion object {
        val KEY = ActionParameters.Key<String>("remoteKey")
    }
}
