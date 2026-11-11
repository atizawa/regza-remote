package com.example.regzaremote.design

import androidx.compose.ui.unit.dp

/**
 * 画面全体で使う余白・大きさ (iOS 版の Design と同じ値)。値はこの 3 段階だけにそろえる
 */
object Design {
    /** 画面の端 */
    val outer = 16.dp

    /** 同じまとまりのボタンの間 */
    val item = 12.dp

    /** まとまりの間 */
    val group = 24.dp

    /** ボタンの高さ: よく使う操作 / ふつう / まれな操作 */
    val primaryHeight = 56.dp
    val regularHeight = 48.dp
    val compactHeight = 40.dp

    val cornerRadius = 16.dp
}
