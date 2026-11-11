package com.example.regzaremote.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalInspectionMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/** Swift の ViewModel の state を、Compose の状態として受け取る (開いていなければ null)。key が変わったら受け取り直す */
@Composable
fun <T> rememberState(key: Any?, states: () -> Flow<T?>): T? {
    val flow = remember(key) { states() }
    // エディタの横のプレビューは、受け取るのを待たずに 1 回だけ描くので、最初の state をその場で受け取っておく
    val inEditor = LocalInspectionMode.current
    val first = remember(key) { if (inEditor) runBlocking { flow.first() } else null }
    return flow.collectAsState(first).value
}
