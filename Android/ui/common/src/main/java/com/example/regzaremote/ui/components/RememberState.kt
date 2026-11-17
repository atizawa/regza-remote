package com.example.regzaremote.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/** STARTED 以上の間、Swift の state を購読する (開いていなければ null)。再開時や key の変更時は最新値を受け取る。 */
@Composable
fun <T> rememberState(key: Any?, states: () -> Flow<T?>): T? {
    val flow = remember(key) { states() }
    // エディタの横のプレビューは、受け取るのを待たずに 1 回だけ描くので、最初の state をその場で受け取っておく
    val inEditor = LocalInspectionMode.current
    val first = remember(key) { if (inEditor) runBlocking { flow.first() } else null }
    return flow.collectAsStateWithLifecycle(initialValue = first).value
}
