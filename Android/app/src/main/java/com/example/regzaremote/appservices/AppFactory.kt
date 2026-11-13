package com.example.regzaremote.appservices

import android.content.Context
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.example.regzaremote.appservices.storage.AndroidStorage
import com.example.regzaremote.core.RegzaAndroid
import com.example.regzaremote.core.RegzaAndroidApp

/** Android の保存先を、通信実装を保持する Swift の Factory に渡す。 */
object AppFactory {
    fun makeApp(context: Context): RegzaAndroidApp = RegzaAndroid.regzaAppFactory().makeApp(AndroidStorage(context.applicationContext))

    fun makeViewModelFactory(context: Context): ViewModelProvider.Factory {
        val applicationContext = context.applicationContext
        return viewModelFactory {
            initializer { RegzaViewModel(makeApp(applicationContext), createSavedStateHandle()) }
        }
    }
}
