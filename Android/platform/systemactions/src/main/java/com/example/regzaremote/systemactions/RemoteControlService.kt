package com.example.regzaremote.systemactions

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.example.regzaremote.appservices.AppFactory
import com.example.regzaremote.appservices.storage.AndroidStorage
import com.example.regzaremote.core.RegzaAndroidAppFactory
import com.example.regzaremote.core.RegzaKey
import com.example.regzaremote.localization.R as StringsR
import kotlinx.coroutines.future.await

/** 画面のない入口から、アプリと同じ保存先・認証・通信でキーを送る (iOS の SystemActions の RegzaKeyIntent にあたる)。 */
class RemoteControlService(private val context: Context, private val remoteFactory: RegzaAndroidAppFactory) {
    companion object {
        /** アプリと同じ通信で作る */
        fun make(context: Context): RemoteControlService = RemoteControlService(context.applicationContext, AppFactory.makeAppFactory())
    }

    suspend fun send(key: RegzaKey): String? {
        if (Build.VERSION.SDK_INT >= 37 &&
            context.checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK) != PackageManager.PERMISSION_GRANTED
        ) {
            return context.getString(StringsR.string.widget_permission_required)
        }
        return remoteFactory.sendRemoteKey(key, AndroidStorage(context)).await().orElse(null)
    }
}
