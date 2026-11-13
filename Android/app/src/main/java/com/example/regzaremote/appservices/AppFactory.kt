package com.example.regzaremote.appservices

import android.content.Context
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.regzaremote.appservices.network.OkHttpTransport
import com.example.regzaremote.appservices.storage.AndroidStorage
import com.example.regzaremote.core.RegzaAndroidApp
import com.example.regzaremote.core.RegzaAndroidAppFactory

/** Android の保存先を、通信実装を保持する Swift の Factory に渡す。 */
object AppFactory {
    private val httpClient by lazy { OkHttpTransport() }

    fun makeApp(context: Context): RegzaAndroidApp =
        RegzaAndroidAppFactory.`init`(httpClient).makeApp(AndroidStorage(context.applicationContext))

    fun makeViewModelFactory(context: Context): ViewModelProvider.Factory {
        val applicationContext = context.applicationContext
        return viewModelFactory {
            initializer { RegzaViewModel(makeApp(applicationContext), createSavedStateHandle()) }
        }
    }
}
