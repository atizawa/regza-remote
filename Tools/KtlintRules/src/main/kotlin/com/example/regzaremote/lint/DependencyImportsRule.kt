package com.example.regzaremote.lint

import com.pinterest.ktlint.rule.engine.core.api.AutocorrectDecision
import com.pinterest.ktlint.rule.engine.core.api.ElementType.IMPORT_DIRECTIVE
import com.pinterest.ktlint.rule.engine.core.api.Rule
import com.pinterest.ktlint.rule.engine.core.api.RuleAutocorrectApproveHandler
import com.pinterest.ktlint.rule.engine.core.api.RuleId
import org.jetbrains.kotlin.com.intellij.lang.ASTNode
import org.jetbrains.kotlin.psi.KtFile
import org.jetbrains.kotlin.psi.KtImportDirective

/** import の境界のみを確認する。型解決や完全修飾名による直接参照は対象外。 */
class DependencyImportsRule :
    Rule(
        RuleId("regza:dependency-imports"),
        About(maintainer = "regza-remote", repositoryUrl = "https://github.com/atizawa/regza-remote"),
    ),
    RuleAutocorrectApproveHandler {
    override fun beforeVisitChildNodes(
        node: ASTNode,
        emit: (offset: Int, errorMessage: String, canBeAutoCorrected: Boolean) -> AutocorrectDecision,
    ) {
        if (node.elementType != IMPORT_DIRECTIVE) return
        val directive = node.psi as KtImportDirective
        val source = (directive.containingFile as KtFile).packageFqName.asString()
        val target = directive.importedFqName?.asString() ?: return
        val ui = "$BASE.ui"
        val services = "$BASE.appservices"
        val design = "$BASE.design"
        val bridge = "$BASE.bridge"
        val previewFactory = "$services.preview.PreviewAppFactory"
        val forbidden = when {
            source.within(ui) -> {
                val previewException = source.within("$ui.preview") && target == previewFactory && !directive.isAllUnder
                (target.within(services) && !previewException) ||
                    target.within("$BASE.core.RegzaAndroidStorage") ||
                    target.within("$BASE.core.RegzaAndroid") ||
                    target.within("$BASE.core.RegzaAndroidBridge") ||
                    target.within("$bridge.AppSend") ||
                    target.within("$BASE.BuildConfig") ||
                    target.within("org.swift.swiftkit") ||
                    target.within("android.content.SharedPreferences") ||
                    target.within("androidx.datastore") ||
                    target.within("androidx.security.crypto")
            }

            source.within(services) || source.within(bridge) -> target.within(ui)

            source.within(design) -> listOf(ui, services, bridge, "$BASE.core").any { target.within(it) }

            else -> false
        }
        if (forbidden) emit(node.startOffset, "Dependency from $source to $target is forbidden", false)
    }

    private fun String.within(prefix: String): Boolean = this == prefix || startsWith("$prefix.")

    private companion object {
        const val BASE = "com.example.regzaremote"
    }
}
