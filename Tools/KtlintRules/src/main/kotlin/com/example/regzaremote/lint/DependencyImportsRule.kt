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
        // 機能の画面 (ui.<機能>) を読み込めるのは、その機能自身と組み立て (ui.app) だけ。
        // 機能は組み立ても読み込まない (ほかの機能の画面は組み立てが渡す)
        val composition = "$ui.app"
        val sourceFeature = featureOf(source)
        val targetFeature = featureOf(target)
        val crossFeature = targetFeature != null && !source.within(composition) && targetFeature != sourceFeature
        val toComposition = sourceFeature != null && target.within(composition)
        val forbidden = when {
            source.within(ui) -> {
                val previewException = source.within("$ui.preview") && target == previewFactory && !directive.isAllUnder
                (target.within(services) && !previewException) ||
                    crossFeature ||
                    toComposition ||
                    target.within("$BASE.core.RegzaAndroidStorage") ||
                    target.within("$BASE.core.RegzaAndroid") ||
                    target.within("$BASE.core.RegzaAndroidBridge") ||
                    target.within("$bridge.SwiftSend") ||
                    target.within("$bridge.SwiftApp") ||
                    target.within("$BASE.BuildConfig") ||
                    target.within("org.swift.swiftkit") ||
                    target.within("android.content.SharedPreferences") ||
                    target.within("androidx.datastore") ||
                    target.within("androidx.security.crypto")
            }

            source.within(services) || source.within(bridge) -> target.within(ui)

            source.within(design) -> listOf(ui, services, bridge, "$BASE.core").any { target.within(it) }

            // 起動の Activity など UI の外も、機能の画面は組み立て (ui.app) を通して使う
            else -> targetFeature != null
        }
        if (forbidden) emit(node.startOffset, "Dependency from $source to $target is forbidden", false)
    }

    private fun String.within(prefix: String): Boolean = this == prefix || startsWith("$prefix.")

    /** 機能の画面の package (ui.<機能>)。ui の下の、共通の部品・プレビューの準備・組み立て以外。機能の画面でなければ null */
    private fun featureOf(name: String): String? {
        val ui = "$BASE.ui"
        if (!name.startsWith("$ui.")) return null
        val first = name.removePrefix("$ui.").substringBefore('.')
        return if (first in NON_FEATURE_UI) null else "$ui.$first"
    }

    private companion object {
        const val BASE = "com.example.regzaremote"

        /** ui の下で、機能の画面ではない package (共通の部品・プレビューの準備・組み立て) */
        val NON_FEATURE_UI = setOf("components", "preview", "app")
    }
}
