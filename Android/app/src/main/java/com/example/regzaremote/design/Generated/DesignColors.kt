// Design/tokens/ から Style Dictionary で生成。直接編集しないでください。
// 更新: mise run generate-design-tokens
package com.example.regzaremote.design

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.example.regzaremote.R

object DesignColors {
    val remoteBackgroundStart: Color
        @Composable get() = colorResource(R.color.remote_background_start)

    val remoteBackgroundEnd: Color
        @Composable get() = colorResource(R.color.remote_background_end)

    val remoteGrayKey: Color
        @Composable get() = colorResource(R.color.remote_gray_key)

    val remotePanel: Color
        @Composable get() = colorResource(R.color.remote_panel)

    val remoteKey: Color
        @Composable get() = colorResource(R.color.remote_key)

    val remoteRing: Color
        @Composable get() = colorResource(R.color.remote_ring)

    val remoteCenterStart: Color
        @Composable get() = colorResource(R.color.remote_center_start)

    val remoteCenterEnd: Color
        @Composable get() = colorResource(R.color.remote_center_end)

    val remotePower: Color
        @Composable get() = colorResource(R.color.remote_power)

    val remoteDestructiveOnGray: Color
        @Composable get() = colorResource(R.color.remote_destructive_on_gray)

    val remoteDestructiveOnBlack: Color
        @Composable get() = colorResource(R.color.remote_destructive_on_black)

    val remoteEdge: Color
        @Composable get() = colorResource(R.color.remote_edge)

    val remoteHighlight: Color
        @Composable get() = colorResource(R.color.remote_highlight)

    val remoteKeyBlue: Color
        @Composable get() = colorResource(R.color.remote_key_blue)

    val remoteKeyRed: Color
        @Composable get() = colorResource(R.color.remote_key_red)

    val remoteKeyGreen: Color
        @Composable get() = colorResource(R.color.remote_key_green)

    val remoteKeyYellow: Color
        @Composable get() = colorResource(R.color.remote_key_yellow)

    val brandAccent: Color
        @Composable get() = colorResource(R.color.brand_accent)

    val brandActivityBackground: Color
        @Composable get() = colorResource(R.color.brand_activity_background)

    val semanticBackground: Color
        @Composable get() = colorResource(R.color.semantic_background)

    val semanticSurface: Color
        @Composable get() = colorResource(R.color.semantic_surface)

    val semanticPrimaryText: Color
        @Composable get() = colorResource(R.color.semantic_primary_text)

    val semanticSecondaryText: Color
        @Composable get() = colorResource(R.color.semantic_secondary_text)

    val semanticFill: Color
        @Composable get() = colorResource(R.color.semantic_fill)

    val semanticSeparator: Color
        @Composable get() = colorResource(R.color.semantic_separator)

    val semanticOrange: Color
        @Composable get() = colorResource(R.color.semantic_orange)

    val semanticRed: Color
        @Composable get() = colorResource(R.color.semantic_red)

    val semanticBlue: Color
        @Composable get() = colorResource(R.color.semantic_blue)

    val semanticOnAccent: Color
        @Composable get() = colorResource(R.color.semantic_on_accent)
}
