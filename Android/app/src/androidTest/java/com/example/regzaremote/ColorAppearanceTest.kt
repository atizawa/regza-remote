package com.example.regzaremote

import android.content.res.Configuration
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.regzaremote.design.AppTheme
import com.example.regzaremote.design.AppearanceTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** 外観変更でAndroid標準リソースを選び直し、Composeの配色へ反映する。 */
@RunWith(AndroidJUnit4::class)
class ColorAppearanceTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun appearanceChangeUpdatesResourceColorsAndMaterialTheme() {
        val dark = mutableStateOf(false)
        compose.setContent {
            val base = LocalContext.current
            val configuration = Configuration(LocalConfiguration.current).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                    if (dark.value) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
            }
            val context = remember(configuration) { base.createConfigurationContext(configuration) }
            CompositionLocalProvider(LocalConfiguration provides configuration, LocalContext provides context) {
                MaterialTheme(colorScheme = AppTheme.colorScheme) {
                    Text(
                        listOf(MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.background, MaterialTheme.colorScheme.onSurface)
                            .joinToString { it.toArgb().toUInt().toString(16) },
                    )
                }
            }
        }
        compose.onNodeWithText("ff006b4f, fff2f2f7, ff000000").assertExists()
        compose.runOnIdle { dark.value = true }
        compose.onNodeWithText("ff1d866f, ff000000, ffffffff").assertExists()
        compose.runOnIdle { dark.value = false }
        compose.onNodeWithText("ff006b4f, fff2f2f7, ff000000").assertExists()
    }

    @Test
    fun selectedAppearanceOverridesSystemAndSystemChoiceResumesFollowingIt() {
        val systemDark = mutableStateOf(true)
        val appearance = mutableStateOf("light")
        compose.setContent {
            val configuration = Configuration(LocalConfiguration.current).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                    if (systemDark.value) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
            }
            CompositionLocalProvider(LocalConfiguration provides configuration) {
                AppearanceTheme(appearance.value) {
                    Text(
                        listOf(AppTheme.background, MaterialTheme.colorScheme.background)
                            .joinToString { it.toArgb().toUInt().toString(16) },
                    )
                }
            }
        }
        compose.onNodeWithText("fff2f2f7, fff2f2f7").assertExists()
        compose.runOnIdle { appearance.value = "dark" }
        compose.onNodeWithText("ff000000, ff000000").assertExists()
        compose.runOnIdle { systemDark.value = false }
        compose.onNodeWithText("ff000000, ff000000").assertExists()
        compose.runOnIdle { appearance.value = "system" }
        compose.onNodeWithText("fff2f2f7, fff2f2f7").assertExists()
        compose.runOnIdle { systemDark.value = true }
        compose.onNodeWithText("ff000000, ff000000").assertExists()
    }
}
