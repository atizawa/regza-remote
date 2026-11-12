package com.example.regzaremote.lint

import com.pinterest.ktlint.cli.ruleset.core.api.RuleSetProviderV3
import com.pinterest.ktlint.rule.engine.core.api.RuleProvider
import com.pinterest.ktlint.rule.engine.core.api.RuleSetId

class RegzaRuleSetProvider : RuleSetProviderV3(RuleSetId("regza")) {
    override fun getRuleProviders(): Set<RuleProvider> = setOf(RuleProvider { DependencyImportsRule() })
}
