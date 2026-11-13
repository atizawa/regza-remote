package com.example.regzaremote.design

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/** 共通のリモコン配色を Compose の面・グラデーションとして使う。 */
internal object RemoteBody {
    val background = Brush.verticalGradient(listOf(DesignColors.remoteBackgroundStart, DesignColors.remoteBackgroundEnd))
    val grayKey = DesignColors.remoteGrayKey
    val panel = DesignColors.remotePanel
    val key = DesignColors.remoteKey
    val edge = DesignColors.remoteEdge
    val ring = DesignColors.remoteRing
    val center = Brush.verticalGradient(listOf(DesignColors.remoteCenterStart, DesignColors.remoteCenterEnd))
    val power = DesignColors.remotePower

    /** 見出しの文字。Compose の文字描画に合わせて指定する。 */
    val sectionText = Color.Black.copy(alpha = 0.6f)
}
