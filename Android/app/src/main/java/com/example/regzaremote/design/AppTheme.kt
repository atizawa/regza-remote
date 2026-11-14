package com.example.regzaremote.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** OS のライト・ダーク設定に従い、共通トークンの標準色リソースを使う。 */
object AppTheme {
    val accent: Color
        @Composable get() = DesignColors.brandAccent

    val background: Color
        @Composable get() = DesignColors.semanticBackground

    val surface: Color
        @Composable get() = DesignColors.semanticSurface

    val fill: Color
        @Composable get() = DesignColors.semanticFill

    val separator: Color
        @Composable get() = DesignColors.semanticSeparator

    val secondaryText: Color
        @Composable get() = DesignColors.semanticSecondaryText

    val orange: Color
        @Composable get() = DesignColors.semanticOrange

    val red: Color
        @Composable get() = DesignColors.semanticRed

    val blue: Color
        @Composable get() = DesignColors.semanticBlue

    val colorScheme: ColorScheme
        @Composable get() {
            val defaults = if (isSystemInDarkTheme()) darkColorScheme() else lightColorScheme()
            return defaults.copy(
                primary = accent,
                onPrimary = DesignColors.semanticOnAccent,
                secondaryContainer = accent,
                onSecondaryContainer = DesignColors.semanticOnAccent,
                background = background,
                onBackground = DesignColors.semanticPrimaryText,
                surface = background,
                onSurface = DesignColors.semanticPrimaryText,
                surfaceContainer = surface,
                surfaceContainerLow = surface,
                surfaceContainerHigh = surface,
                onSurfaceVariant = secondaryText,
                outlineVariant = separator,
                error = red,
            )
        }
}
