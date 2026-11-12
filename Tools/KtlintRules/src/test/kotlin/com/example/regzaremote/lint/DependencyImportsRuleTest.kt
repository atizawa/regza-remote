package com.example.regzaremote.lint

import com.pinterest.ktlint.test.KtLintAssertThat.Companion.assertThatRule
import org.junit.jupiter.api.Test

class DependencyImportsRuleTest {
    private val rule = assertThatRule { DependencyImportsRule() }
    private val base = "com.example.regzaremote"

    @Test
    fun `UI rejects DI and storage including aliases and wildcard imports`() {
        listOf(
            "$base.appservices.AppFactory",
            "$base.appservices.storage.AndroidStorage as Storage",
            "$base.appservices.*",
            "$base.core.RegzaAndroidStorage",
            "$base.core.RegzaAndroid",
            "$base.core.RegzaAndroidBridge",
            "$base.bridge.AppSend",
            "$base.BuildConfig",
            "org.swift.swiftkit.core.SwiftLibraries",
            "android.content.SharedPreferences",
            "androidx.datastore.preferences.core.Preferences",
            "androidx.security.crypto.EncryptedSharedPreferences",
        ).forEach { rejects("$base.ui.screens", it) }
    }

    @Test
    fun `only preview UI may import the preview factory`() {
        allows("$base.ui.preview", "$base.appservices.preview.PreviewAppFactory")
        rejects("$base.ui.screens", "$base.appservices.preview.PreviewAppFactory")
        rejects("$base.ui.preview", "$base.appservices.AppFactory")
        rejects("$base.ui.preview", "$base.appservices.preview.*")
        rejects("$base.ui.preview", "$base.appservices.preview.PreviewAppFactory.makeApp")
    }

    @Test
    fun `services and bridge reject dependencies on UI`() {
        rejects("$base.appservices", "$base.ui.screens.HomeScreen")
        rejects("$base.appservices.storage", "$base.ui.components.Note")
        rejects("$base.bridge", "$base.ui.components.Note")
    }

    @Test
    fun `design rejects application layers`() {
        listOf("ui.components.Note", "appservices.AppFactory", "bridge.Send", "core.AppState")
            .forEach { rejects("$base.design", "$base.$it") }
    }

    @Test
    fun `normal dependencies and application composition are allowed`() {
        listOf(
            "$base.ui.screens" to "$base.core.AppState",
            "$base.ui.screens" to "$base.core.RegzaAndroidApp",
            "$base.ui.screens" to "$base.bridge.Send",
            "$base.ui.screens" to "$base.design.Design",
            "$base.ui.screens" to "$base.ui.components.Note",
            "$base.ui.screens" to "androidx.compose.runtime.Composable",
            "$base.ui.screens" to "androidx.media3.exoplayer.ExoPlayer",
            "$base.ui.screens" to "$base.appservicesOther.Example",
            "$base.design" to "androidx.compose.ui.Modifier",
            "$base.appservices" to "$base.core.RegzaAndroid",
            "$base.appservices.storage" to "$base.core.RegzaAndroidStorage",
            base to "$base.appservices.AppFactory",
            base to "$base.ui.screens.HomeScreen",
            "other.feature" to "$base.appservices.AppFactory",
        ).forEach { (source, target) -> allows(source, target) }
    }

    @Test
    fun `comments and strings are not imports`() {
        rule(
            """
            package $base.ui.screens

            // import $base.appservices.AppFactory
            /* import $base.appservices.storage.AndroidStorage */
            val text = "import $base.appservices.AppFactory"
            """.trimIndent(),
        ).hasNoLintViolations()
    }

    private fun allows(source: String, target: String) {
        rule("package $source\n\nimport $target\n").hasNoLintViolations()
    }

    private fun rejects(source: String, target: String) {
        val imported = target.substringBefore(" as ").removeSuffix(".*")
        rule("package $source\n\nimport $target\n")
            .hasLintViolationWithoutAutoCorrect(3, 1, "Dependency from $source to $imported is forbidden")
    }
}
