package com.example.regzaremote.lint

import com.pinterest.ktlint.rule.engine.core.api.AutocorrectDecision
import com.pinterest.ktlint.rule.engine.core.api.Rule
import com.pinterest.ktlint.rule.engine.core.api.RuleAutocorrectApproveHandler
import com.pinterest.ktlint.rule.engine.core.api.RuleId
import org.jetbrains.kotlin.com.intellij.lang.ASTNode
import org.jetbrains.kotlin.lexer.KtTokens
import org.jetbrains.kotlin.psi.KtBinaryExpression
import org.jetbrains.kotlin.psi.KtCallExpression
import org.jetbrains.kotlin.psi.KtDotQualifiedExpression
import org.jetbrains.kotlin.psi.KtExpression
import org.jetbrains.kotlin.psi.KtNameReferenceExpression
import org.jetbrains.kotlin.psi.KtParenthesizedExpression
import org.jetbrains.kotlin.psi.KtSafeQualifiedExpression
import org.jetbrains.kotlin.psi.KtStringTemplateExpression
import org.jetbrains.kotlin.psi.KtWhenConditionWithExpression
import org.jetbrains.kotlin.psi.KtWhenExpression

/**
 * Swift の enum の case を、文字列 (rawValue) で見分けることを禁じる。
 * 文字列だと Swift で case の名前を変えてもコンパイルが通り、黙って表示や動きがずれる。
 * swift-java が作る Discriminator (Java の enum) で比べれば、名前の変更はコンパイルで分かり、when で全部の case を扱っているかも確かめられる。
 *
 * 型は解決しないので、名前で見分ける: `rawValue` と文字列リテラルの比較・`when (….rawValue)` の文字列の枝・
 * 文字列リテラルを渡す `` `init`("…") `` (raw value から case を作る swift-java の関数)
 */
class SwiftEnumLiteralRule :
    Rule(
        RuleId("regza:swift-enum-literal"),
        About(maintainer = "regza-remote", repositoryUrl = "https://github.com/atizawa/regza-remote"),
    ),
    RuleAutocorrectApproveHandler {
    override fun beforeVisitChildNodes(
        node: ASTNode,
        emit: (offset: Int, errorMessage: String, canBeAutoCorrected: Boolean) -> AutocorrectDecision,
    ) {
        when (val psi = node.psi) {
            is KtBinaryExpression -> {
                val operator = psi.operationToken
                if (operator != KtTokens.EQEQ && operator != KtTokens.EXCLEQ) return
                val left = psi.left ?: return
                val right = psi.right ?: return
                if ((left.isRawValue() && right.isStringLiteral()) || (left.isStringLiteral() && right.isRawValue())) {
                    emit(node.startOffset, MESSAGE, false)
                }
            }

            is KtWhenExpression -> {
                if (psi.subjectExpression?.isRawValue() != true) return
                val literals = psi.entries.flatMap { it.conditions.toList() }
                    .filterIsInstance<KtWhenConditionWithExpression>()
                    .any { it.expression?.isStringLiteral() == true }
                if (literals) emit(node.startOffset, MESSAGE, false)
            }

            is KtCallExpression -> {
                val callee = psi.calleeExpression as? KtNameReferenceExpression ?: return
                if (callee.getReferencedName() != "init") return
                val arguments = psi.valueArguments
                if (arguments.size == 1 && arguments.single().getArgumentExpression()?.isStringLiteral() == true) {
                    emit(node.startOffset, MESSAGE, false)
                }
            }
        }
    }

    /** `….rawValue` (安全呼び出し `?.rawValue` も含む) */
    private fun KtExpression.isRawValue(): Boolean {
        val expression = unwrapped()
        val selector = when (expression) {
            is KtDotQualifiedExpression -> expression.selectorExpression
            is KtSafeQualifiedExpression -> expression.selectorExpression
            else -> return false
        }
        return (selector as? KtNameReferenceExpression)?.getReferencedName() == "rawValue"
    }

    /** 埋め込みのない文字列リテラル */
    private fun KtExpression.isStringLiteral(): Boolean {
        val expression = unwrapped()
        return expression is KtStringTemplateExpression && !expression.hasInterpolation()
    }

    private fun KtExpression.unwrapped(): KtExpression = if (this is KtParenthesizedExpression) expression?.unwrapped() ?: this else this

    private companion object {
        const val MESSAGE = "Compare Swift enum cases with their Discriminator, not with rawValue strings"
    }
}
