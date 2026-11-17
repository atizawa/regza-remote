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
        ).forEach { rejects("$base.ui.guide", it) }
    }

    @Test
    fun `only preview UI may import the preview factory`() {
        allows("$base.ui.preview", "$base.appservices.preview.PreviewAppFactory")
        rejects("$base.ui.guide", "$base.appservices.preview.PreviewAppFactory")
        rejects("$base.ui.preview", "$base.appservices.AppFactory")
        rejects("$base.ui.preview", "$base.appservices.preview.*")
        rejects("$base.ui.preview", "$base.appservices.preview.PreviewAppFactory.makeApp")
    }

    @Test
    fun `features reject other features and the composition`() {
        rejects("$base.ui.guide", "$base.ui.program.ProgramDetailScreen")
        rejects("$base.ui.guide", "$base.ui.program.*")
        rejects("$base.ui.guide.parts", "$base.ui.channels.ChannelListScreen")
        rejects("$base.ui.guide", "$base.ui.app.AppScreen")
        allows("$base.ui.guide.parts", "$base.ui.guide.GuideGridScreen")
        allows("$base.ui.guide", "$base.ui.components.BandPicker")
        allows("$base.ui.guide", "$base.ui.preview.FakePreview")
        allows("$base.ui.app", "$base.ui.guide.GuideGridScreen")
    }

    @Test
    fun `only the composition imports features from shared UI`() {
        rejects("$base.ui.components", "$base.ui.program.ProgramDetailScreen")
        rejects("$base.ui.preview", "$base.ui.guide.GuideGridScreen")
        // 機能の名前のない package は、どの機能でもないので読み込めない
        rejects("$base.ui", "$base.ui.guide.GuideGridScreen")
        // UI の外 (起動の Activity など) も、組み立てを通して使う
        rejects(base, "$base.ui.player.LivePlayerScreen")
        allows(base, "$base.ui.app.AppRoot")
    }

    @Test
    fun `services and bridge reject dependencies on UI`() {
        rejects("$base.appservices", "$base.ui.guide.GuideGridScreen")
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
            "$base.ui.guide" to "$base.core.AppState",
            "$base.ui.guide" to "$base.core.RegzaAndroidApp",
            "$base.ui.guide" to "$base.bridge.Send",
            "$base.ui.guide" to "$base.design.Design",
            "$base.ui.guide" to "$base.ui.components.Note",
            "$base.ui.guide" to "androidx.compose.runtime.Composable",
            "$base.ui.guide" to "androidx.media3.exoplayer.ExoPlayer",
            "$base.ui.guide" to "$base.appservicesOther.Example",
            "$base.design" to "androidx.compose.ui.Modifier",
            "$base.appservices" to "$base.core.RegzaAndroid",
            "$base.appservices.storage" to "$base.core.RegzaAndroidStorage",
            base to "$base.appservices.AppFactory",
            base to "$base.ui.app.AppScreen",
            "other.feature" to "$base.appservices.AppFactory",
        ).forEach { (source, target) -> allows(source, target) }
    }

    @Test
    fun `comments and strings are not imports`() {
        rule(
            """
            package $base.ui.guide

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
