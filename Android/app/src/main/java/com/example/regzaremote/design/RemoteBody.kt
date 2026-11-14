package com.example.regzaremote.design

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/** 共通のリモコン配色を Compose の面・グラデーションとして使う。 */
internal object RemoteBody {
    val background: Brush
        @Composable get() = Brush.verticalGradient(listOf(DesignColors.remoteBackgroundStart, DesignColors.remoteBackgroundEnd))
    val grayKey: Color
        @Composable get() = DesignColors.remoteGrayKey
    val panel: Color
        @Composable get() = DesignColors.remotePanel
    val key: Color
        @Composable get() = DesignColors.remoteKey
    val edge: Color
        @Composable get() = DesignColors.remoteEdge
    val ring: Color
        @Composable get() = DesignColors.remoteRing
    val center: Brush
        @Composable get() = Brush.verticalGradient(listOf(DesignColors.remoteCenterStart, DesignColors.remoteCenterEnd))
    val power: Color
        @Composable get() = DesignColors.remotePower

    /** 見出しの文字。Compose の文字描画に合わせて指定する。 */
    val sectionText = Color.Black.copy(alpha = 0.6f)
}
