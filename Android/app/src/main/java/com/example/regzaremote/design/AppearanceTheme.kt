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

/**
 * 選択した外観で標準リソース・Material・システムバーの配色をそろえる。
 * dark が null ならシステムに合わせる (design は Swift の型を読み込まないので、呼び出し側が外観の選択から決めて渡す)
 */
@Composable
fun AppearanceTheme(dark: Boolean?, content: @Composable () -> Unit) {
    val base = LocalContext.current
    val original = LocalConfiguration.current
    val mode = when (dark) {
        false -> Configuration.UI_MODE_NIGHT_NO
        true -> Configuration.UI_MODE_NIGHT_YES
        null -> original.uiMode and Configuration.UI_MODE_NIGHT_MASK
    }
    val configuration = Configuration(original).apply {
        uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
    }
    val context = remember(base, configuration) {
        ContextThemeWrapper(base, R.style.Theme_RegzaRemote).apply { applyOverrideConfiguration(configuration) }
    }
    val activity = LocalActivity.current
    val isDark = mode == Configuration.UI_MODE_NIGHT_YES
    DisposableEffect(activity, isDark) {
        val style = SystemBarStyle.auto(AndroidColor.TRANSPARENT, AndroidColor.TRANSPARENT) { isDark }
        (activity as? androidx.activity.ComponentActivity)?.enableEdgeToEdge(style, style)
        onDispose { }
    }
    CompositionLocalProvider(LocalConfiguration provides configuration, LocalContext provides context) {
        MaterialTheme(colorScheme = AppTheme.colorScheme, content = content)
    }
}
