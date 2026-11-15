package com.example.regzaremote.lint

import com.pinterest.ktlint.test.KtLintAssertThat.Companion.assertThatRule
import org.junit.jupiter.api.Test

class SwiftEnumLiteralRuleTest {
    private val rule = assertThatRule { SwiftEnumLiteralRule() }
    private val message = "Compare Swift enum cases with their Discriminator, not with rawValue strings"

    @Test
    fun `rawValue compared with a string literal is rejected`() {
        listOf(
            "val a = key.rawValue == \"power\"",
            "val a = \"power\" != key.rawValue",
            "val a = state.kind?.rawValue == \"recorded\"",
            "val a = (key.rawValue) == (\"power\")",
        ).forEach { rejects(it) }
    }

    @Test
    fun `when over rawValue with string branches is rejected`() {
        rejects("val a = when (tab.rawValue) {\n    \"guide\" -> 1\n    else -> 0\n}")
    }

    @Test
    fun `creating a case from a string literal is rejected`() {
        // 呼び出し (`init`) の位置を指す
        rejects("val a = RegzaKey.`init`(\"num1\")", column = 18)
    }

    @Test
    fun `discriminators and non literal raw values are allowed`() {
        listOf(
            "val a = key.discriminator == RegzaKey.Discriminator.POWER",
            "val a = when (tab.discriminator) {\n    AppTab.Discriminator.GUIDE -> 1\n    else -> 0\n}",
            // 識別子として使うだけ・Swift の値どうしの比較・外から受け取った文字列から作る
            "val a = \"tab.\${tab.rawValue}\"",
            "val a = selected.rawValue == tab.rawValue",
            "val a = RegzaKey.`init`(name)",
            "val a = RegzaKey.`init`(\"num\$index\")",
            "val a = name == \"power\"",
            "val a = when (value) {\n    \"light\" -> 1\n    else -> 0\n}",
        ).forEach { rule("$it\n").hasNoLintViolations() }
    }

    private fun rejects(code: String, column: Int = 9) {
        rule("$code\n").hasLintViolationWithoutAutoCorrect(1, column, message)
    }
}
