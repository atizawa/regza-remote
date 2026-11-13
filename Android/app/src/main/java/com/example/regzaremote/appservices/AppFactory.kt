package com.example.regzaremote.appservices

import android.content.Context
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.regzaremote.BuildConfig
import com.example.regzaremote.appservices.network.OkHttpTransport
import com.example.regzaremote.appservices.storage.AndroidStorage
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidAppFactory
import com.example.regzaremote.core.RegzaAndroidStorage
import java.util.Optional

/** Android の保存先を、通信実装を保持する Swift の Factory に渡す。 */
object AppFactory {
    private val httpClient by lazy { OkHttpTransport() }

    fun makeApp(context: Context): RegzaAndroidApp =
        RegzaAndroidAppFactory.`init`(httpClient).makeApp(AndroidStorage(context.applicationContext))

    fun makeViewModelFactory(context: Context, testServer: String? = null): ViewModelProvider.Factory {
        val applicationContext = context.applicationContext
        return viewModelFactory {
            initializer {
                val app = if (BuildConfig.DEBUG && testServer != null) {
                    RegzaAndroidAppFactory.`init`(httpClient).makeApp(UITestStorage(testServer))
                } else {
                    makeApp(applicationContext)
                }
                RegzaViewModel(app, createSavedStateHandle())
            }
        }
    }

    private class UITestStorage(server: String) : RegzaAndroidStorage {
        private val values = mutableMapOf("host" to server, "guideHost" to server, "streamHost" to server)
        override fun value(key: String): Optional<String> = Optional.ofNullable(values[key])
        override fun setValue(value: String, key: String) {
            values[key] = value
        }
    }
}
