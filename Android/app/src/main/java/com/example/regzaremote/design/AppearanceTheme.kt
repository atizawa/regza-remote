package com.example.regzaremote.design

import android.content.res.Configuration
import android.graphics.Color as AndroidColor
import android.view.ContextThemeWrapper
import androidx.activity.SystemBarStyle
import androidx.activity.compose.LocalActivity
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import com.example.regzaremote.R

/** 選択した外観で標準リソース・Material・システムバーの配色をそろえる。 */
@Composable
fun AppearanceTheme(appearance: String, content: @Composable () -> Unit) {
    val base = LocalContext.current
    val original = LocalConfiguration.current
    val mode = when (appearance) {
        "light" -> Configuration.UI_MODE_NIGHT_NO
        "dark" -> Configuration.UI_MODE_NIGHT_YES
        else -> original.uiMode and Configuration.UI_MODE_NIGHT_MASK
    }
    val configuration = Configuration(original).apply {
        uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
    }
    val context = remember(base, configuration) {
        ContextThemeWrapper(base, R.style.Theme_RegzaRemote).apply { applyOverrideConfiguration(configuration) }
    }
    val activity = LocalActivity.current
    val dark = mode == Configuration.UI_MODE_NIGHT_YES
    DisposableEffect(activity, dark) {
        val style = SystemBarStyle.auto(AndroidColor.TRANSPARENT, AndroidColor.TRANSPARENT) { dark }
        (activity as? androidx.activity.ComponentActivity)?.enableEdgeToEdge(style, style)
        onDispose { }
    }
    CompositionLocalProvider(LocalConfiguration provides configuration, LocalContext provides context) {
        MaterialTheme(colorScheme = AppTheme.colorScheme, content = content)
    }
}
