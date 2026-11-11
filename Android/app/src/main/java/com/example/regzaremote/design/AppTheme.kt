package com.example.regzaremote.design

import androidx.compose.material3.darkColorScheme
import androidx.compose.ui.graphics.Color

/** アプリの色 (iOS 版の AppTheme と同じ)。ダークに固定し、ボタンや選択中の印は明るめの緑にする */
object AppTheme {
    val accent = Color(0xFF1D866F)

    /** iOS の systemGroupedBackground・secondarySystemGroupedBackground (ダーク) に合わせた面の色 */
    val background = Color.Black
    val surface = Color(0xFF1C1C1E)

    /** 日付やポートなど、控えめな塗り (iOS の .fill.tertiary) */
    val fill = Color(0x3D767680)
    val separator = Color(0x5C545458)
    val secondaryText = Color(0x99EBEBF5)
    val orange = Color(0xFFFF9F0A)
    val red = Color(0xFFFF453A)
    val blue = Color(0xFF0A84FF)

    val colorScheme = darkColorScheme(
        primary = accent,
        onPrimary = Color.White,
        secondaryContainer = accent,
        onSecondaryContainer = Color.White,
        background = background,
        surface = background,
        surfaceContainer = surface,
        surfaceContainerLow = surface,
        surfaceContainerHigh = surface,
        onSurfaceVariant = secondaryText,
        outlineVariant = separator,
        error = red,
    )
}
