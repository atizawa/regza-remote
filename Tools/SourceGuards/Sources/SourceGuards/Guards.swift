import SwiftSyntax

/// 型やモジュールの依存では守れない決まりの見張り。決まりと理由は docs/architecture.md にある
public enum Guards {
    // MARK: - 時計

    /// 今の時刻を直接読むところ。時刻は時計 (AppClock) から読む。
    /// - Date を作る: `Date()`・`Foundation.Date()`・`Date.init()`・`Date(timeIntervalSinceNow:)`、型を書いた先の `.init()`
    /// - 今の時刻を読む: `Date.now`・`Date.timeIntervalSinceReferenceDate`、`.timeIntervalSinceNow`、`CFAbsoluteTimeGetCurrent()`、型を省いた `.now`
    ///   (構文だけでは Date か ContinuousClock かを見分けられないので、型を省いた `.now` は書かない。`ContinuousClock.now` などと書く)
    public static func clockReads(in file: SourceFile) -> [Finding] {
        file.nodes.compactMap { node in
            if let call = node.as(FunctionCallExprSyntax.self), call.trailingClosure == nil {
                let labels = call.arguments.map { $0.label?.text }
                let readsNow = labels.isEmpty || labels == ["timeIntervalSinceNow"]
                let callee = call.calledExpression
                if readsNow, isDate(callee) { return Finding(file, call) }
                if labels.isEmpty, callee.as(DeclReferenceExprSyntax.self)?.baseName.text == "CFAbsoluteTimeGetCurrent" {
                    return Finding(file, call)
                }
                if readsNow, let member = callee.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "init",
                    member.base.map(isDate) ?? isAssignedToDate(member)
                {
                    return Finding(file, call)
                }
            }
            guard let member = node.as(MemberAccessExprSyntax.self) else { return nil }
            switch member.declName.baseName.text {
            case "now": return member.base.map(isDate) ?? true ? Finding(file, member) : nil
            case "timeIntervalSinceNow": return member.base == nil ? nil : Finding(file, member)
            case "timeIntervalSinceReferenceDate": return member.base.map(isDate) == true ? Finding(file, member) : nil
            default: return nil
            }
        }
    }

    /// Date の型 (`Date`・`Foundation.Date`) か
    private static func isDate(_ expression: ExprSyntax) -> Bool {
        if let reference = expression.as(DeclReferenceExprSyntax.self) { return reference.baseName.text == "Date" }
        guard let member = expression.as(MemberAccessExprSyntax.self) else { return false }
        return member.declName.baseName.text == "Date" && member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "Foundation"
    }

    /// 型を省いた値を入れる先の、書いた型 (型を書いた変数にそのまま入れるときだけ分かる。関数の引数の中なら分からない)
    private static func assignedType(of member: MemberAccessExprSyntax) -> String? {
        var node = Syntax(member)
        while let parent = node.parent {
            if let binding = parent.as(PatternBindingSyntax.self) { return binding.typeAnnotation?.type.trimmedDescription }
            if parent.is(CodeBlockItemSyntax.self) || parent.is(ClosureExprSyntax.self) || parent.is(LabeledExprSyntax.self) {
                return nil
            }
            node = parent
        }
        return nil
    }

    private static let dateTypes: Set<String> = ["Date", "Date?", "Foundation.Date", "Foundation.Date?"]

    /// 型を書いて Date に入れる
    private static func isAssignedToDate(_ member: MemberAccessExprSyntax) -> Bool {
        assignedType(of: member).map(dateTypes.contains) ?? false
    }

    // MARK: - エラーの文言

    /// エラーの文言を直接読むところ (`.localizedDescription` と、キーパスの `\.localizedDescription`)。画面に出す文言は ErrorMessage で作る
    public static func localizedDescriptionReads(in file: SourceFile) -> [Finding] {
        file.nodes.compactMap { node in
            let name =
                node.as(MemberAccessExprSyntax.self)?.declName.baseName.text
                ?? node.as(KeyPathPropertyComponentSyntax.self)?.declName.baseName.text
            return name == "localizedDescription" ? Finding(file, node) : nil
        }
    }

    // MARK: - ViewModel が UseCase をどう持つか

    /// UseCase を private 以外で持つプロパティ。型の名前が exempt のもの (と、その extension) と、protocol の要件は除く
    public static func nonPrivateUseCases(in file: SourceFile, exempt: Set<String>) -> [Finding] {
        topLevelItems(file.tree.statements).compactMap { memberBlock(of: $0, exempt: exempt) }.flatMap { members in
            variables(in: members.members).filter { holdsUseCase($0) && !isPrivate($0.modifiers) }.map { Finding(file, $0) }
        }
    }

    /// ファイル直下の宣言 (#if の中も含む)
    private static func topLevelItems(_ statements: CodeBlockItemListSyntax) -> [CodeBlockItemSyntax.Item] {
        statements.flatMap { statement -> [CodeBlockItemSyntax.Item] in
            guard let conditions = statement.item.as(IfConfigDeclSyntax.self) else { return [statement.item] }
            return conditions.clauses.flatMap { clause -> [CodeBlockItemSyntax.Item] in
                guard case .statements(let inner) = clause.elements else { return [] }
                return topLevelItems(inner)
            }
        }
    }

    /// 一番外の型の宣言の中身。見張らないもの (exempt の型・その extension・protocol) なら nil
    private static func memberBlock(of item: CodeBlockItemSyntax.Item, exempt: Set<String>) -> MemberBlockSyntax? {
        guard let declaration = item.as(DeclSyntax.self) else { return nil }
        if let type = declaration.asProtocol(NamedDeclSyntax.self), let group = declaration.asProtocol(DeclGroupSyntax.self) {
            return declaration.is(ProtocolDeclSyntax.self) || exempt.contains(type.name.text) ? nil : group.memberBlock
        }
        if let extensionDecl = declaration.as(ExtensionDeclSyntax.self) {
            // 除くのはその型の extension だけ。入れ子の型 (A.B) の extension は見張る
            return exempt.contains(extensionDecl.extendedType.trimmedDescription) ? nil : extensionDecl.memberBlock
        }
        return nil
    }

    /// 型の中のプロパティ (#if の中と、入れ子の型の中も含む。入れ子の protocol の要件は除く)
    private static func variables(in members: MemberBlockItemListSyntax) -> [VariableDeclSyntax] {
        members.flatMap { member -> [VariableDeclSyntax] in
            if let variable = member.decl.as(VariableDeclSyntax.self) { return [variable] }
            if let nested = member.decl.asProtocol(DeclGroupSyntax.self) {
                return member.decl.is(ProtocolDeclSyntax.self) ? [] : variables(in: nested.memberBlock.members)
            }
            guard let conditions = member.decl.as(IfConfigDeclSyntax.self) else { return [] }
            return conditions.clauses.flatMap { clause -> [VariableDeclSyntax] in
                guard case .decls(let decls) = clause.elements else { return [] }
                return variables(in: decls)
            }
        }
    }

    /// 型が UseCase を含む (省略できる型や配列も) か、UseCase を作って入れる
    private static func holdsUseCase(_ variable: VariableDeclSyntax) -> Bool {
        variable.bindings.contains { binding in
            if let type = binding.typeAnnotation?.type, type.trimmedDescription.contains("UseCase") { return true }
            guard let value = binding.initializer?.value else { return false }
            return value.trimmedDescription.firstMatch(of: /^\w*UseCase\b/) != nil
        }
    }

    /// private (private(set) は読む側が private ではないので除く)
    private static func isPrivate(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.tokenKind == .keyword(.private) && $0.detail == nil }
    }

    /// 自分 (self) 以外が持つ UseCase のプロパティを読むところ。型の名前や関数の呼び出しは除く
    public static func borrowedUseCases(in file: SourceFile) -> [Finding] {
        file.nodes.compactMap { node in
            guard let member = node.as(MemberAccessExprSyntax.self), let base = member.base,
                member.declName.baseName.text.firstMatch(of: /^[a-z]\w*UseCase$/) != nil
            else { return nil }
            // 関数の呼び出し (<名前>.<名前>UseCase() の形) は除く
            if let call = member.parent?.as(FunctionCallExprSyntax.self), call.calledExpression.id == member.id { return nil }
            var owner = base
            while let inner = owner.as(OptionalChainingExprSyntax.self)?.expression ?? owner.as(ForceUnwrapExprSyntax.self)?.expression {
                owner = inner
            }
            // 自分のものと、型 (大文字で始まる名前) のものは除く
            if let name = owner.as(DeclReferenceExprSyntax.self)?.baseName.text, name == "self" || name.first?.isUppercase == true {
                return nil
            }
            return Finding(file, member)
        }
    }

    // MARK: - 約束事 (CLI と振る舞いのテスト) の操作

    /// 画面の Action の型 (Action/ に置いた public enum) と、その case
    public struct ActionType: Equatable {
        public var name: String
        public var cases: [String]
        public var path: String

        public init(name: String, cases: [String], path: String) {
            self.name = name
            self.cases = cases
            self.path = path
        }
    }

    /// Action/ に置いたファイルの、public enum とその case
    public static func actionTypes(in files: [SourceFile]) -> [ActionType] {
        files.filter { $0.path.contains("/Action/") }.compactMap { file in
            for statement in file.tree.statements {
                guard let enumDecl = statement.item.as(EnumDeclSyntax.self),
                    enumDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.public) })
                else { continue }
                let cases = enumDecl.memberBlock.members.flatMap { member in
                    member.decl.as(EnumCaseDeclSyntax.self)?.elements.map(\.name.text) ?? []
                }
                return ActionType(name: enumDecl.name.text, cases: cases, path: file.path)
            }
            return nil
        }
    }

    /// 操作の表 (`introspectionTable: [IntrospectionAction<型>]`) ごとの、表が作る Action の case の名前。
    /// 型が `Action` なら、同じファイルの `typealias Action = 型` の型にする。
    /// 作る case は、操作 (`IntrospectionAction(…)`) の 3 つ目の値と、操作や部品の包み直し (`prefixed`) の閉じた処理が返す値の
    /// いちばん外の case (`.<case>(.<別の型の case>)` なら外の case)
    public static func tables(in files: [SourceFile]) -> [String: [String]] {
        var tables: [String: [String]] = [:]
        for file in files {
            let nodes = file.nodes
            // 画面の Action の型は、一番外の型 (と、その extension) に書いた typealias で決める (入れ子の型のものは使わない)
            let alias = nodes.lazy.compactMap { $0.as(TypeAliasDeclSyntax.self) }
                .first { $0.name.text == "Action" && isInOutermostType($0) }?.initializer.value.trimmedDescription
            for binding in nodes.compactMap({ $0.as(PatternBindingSyntax.self) }) {
                guard binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "introspectionTable",
                    let element = binding.typeAnnotation?.type.as(ArrayTypeSyntax.self)?.element.as(IdentifierTypeSyntax.self),
                    element.name.text == "IntrospectionAction",
                    let argument = element.genericArgumentClause?.arguments.first?.argument.trimmedDescription
                else { continue }
                let type = argument == "Action" ? alias ?? argument : argument
                tables[type, default: []] += producedCases(in: binding)
            }
        }
        return tables
    }

    /// 表の中で作る Action の case の名前
    private static func producedCases(in table: PatternBindingSyntax) -> [String] {
        table.descendants().compactMap { $0.as(FunctionCallExprSyntax.self) }.flatMap { call -> [String] in
            let callee = call.calledExpression
            let isEntry = callee.as(DeclReferenceExprSyntax.self)?.baseName.text == "IntrospectionAction"
            let isPrefixed = callee.as(MemberAccessExprSyntax.self)?.declName.baseName.text == "prefixed"
            guard isEntry || isPrefixed else { return [] }
            // Action を作る閉じた処理 (後ろに置いたものか、名前を付けた make:)
            let closure =
                call.trailingClosure ?? call.arguments.first { $0.label?.text == "make" }?.expression.as(ClosureExprSyntax.self)
            if let closure { return results(of: closure).flatMap(caseNames) }
            // 閉じた処理がなければ、いつでも送れる操作の値 (名前・説明に続く 3 つ目)
            guard isEntry, call.arguments.count == 3, let value = call.arguments.last, value.label == nil else { return [] }
            return caseNames(value.expression)
        }
    }

    /// 操作の表ごとの、同じ名前の操作 (表の中の `IntrospectionAction("<名前>", …)` の名前が重なるもの)。重なると後ろの操作を送れない
    public static func duplicateActionNames(in file: SourceFile) -> [Finding] {
        file.nodes.compactMap { $0.as(PatternBindingSyntax.self) }
            .filter { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "introspectionTable" }
            .flatMap { table -> [Finding] in
                var seen: Set<String> = []
                return table.descendants().compactMap { $0.as(FunctionCallExprSyntax.self) }.compactMap { call in
                    guard call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "IntrospectionAction",
                        let literal = call.arguments.first?.expression.as(StringLiteralExprSyntax.self)
                    else { return nil }
                    return seen.insert(literal.segments.trimmedDescription).inserted ? nil : Finding(file, call)
                }
            }
    }

    /// 文の式 (式そのものか、文の位置に置いた式 (if・switch の式など))
    private static func expressionOf(_ item: CodeBlockItemSyntax.Item) -> ExprSyntax? {
        item.as(ExprSyntax.self) ?? item.as(ExpressionStmtSyntax.self)?.expression
    }

    /// 閉じた処理が返す値 (1 つの式だけなら、その式。ほかは return の値。中の閉じた処理の return は除く)
    private static func results(of closure: ClosureExprSyntax) -> [ExprSyntax] {
        if closure.statements.count == 1, let expression = closure.statements.first.flatMap({ expressionOf($0.item) }) {
            return [expression]
        }
        var results: [ExprSyntax] = []
        func walk(_ node: Syntax) {
            if node.is(ClosureExprSyntax.self) { return }
            if let value = node.as(ReturnStmtSyntax.self)?.expression { results.append(value) }
            for child in node.children(viewMode: .sourceAccurate) { walk(child) }
        }
        for statement in closure.statements { walk(Syntax(statement)) }
        return results
    }

    /// 値のいちばん外の case の名前 (`.<case>(<値>)` の case。try は外す。条件で選ぶ式 (三項演算子・if・switch) は、どの枝の case も)
    private static func caseNames(_ expression: ExprSyntax) -> [String] {
        if let inner = expression.as(TryExprSyntax.self)?.expression { return caseNames(inner) }
        if let ternary = expression.as(TernaryExprSyntax.self) {
            return caseNames(ternary.thenExpression) + caseNames(ternary.elseExpression)
        }
        // 演算子を組み立てる前の三項演算子 (<条件> ? <値> : <値> の並び)
        if let sequence = expression.as(SequenceExprSyntax.self),
            let index = sequence.elements.firstIndex(where: { $0.is(UnresolvedTernaryExprSyntax.self) }),
            let ternary = sequence.elements[index].as(UnresolvedTernaryExprSyntax.self), let last = sequence.elements.last
        {
            return caseNames(ternary.thenExpression) + caseNames(last)
        }
        if expression.is(IfExprSyntax.self) || expression.is(SwitchExprSyntax.self) {
            // 枝ごとの、最後の式
            return expression.descendants().compactMap { $0.as(CodeBlockItemListSyntax.self) }
                .filter { list in list.parent.map { $0.is(CodeBlockSyntax.self) || $0.is(SwitchCaseSyntax.self) } ?? false }
                .compactMap { $0.last.flatMap { expressionOf($0.item) } }
                .flatMap(caseNames)
        }
        if let call = expression.as(FunctionCallExprSyntax.self) { return caseNames(call.calledExpression) }
        guard let member = expression.as(MemberAccessExprSyntax.self), member.base == nil else { return [] }
        return [member.declName.baseName.text]
    }

    /// 宣言が、ファイル直下の型 (か extension) のすぐ中にある
    private static func isInOutermostType(_ declaration: some SyntaxProtocol) -> Bool {
        var node = Syntax(declaration)
        while let parent = node.parent {
            if parent.asProtocol(DeclGroupSyntax.self) != nil {
                return parent.parent?.is(CodeBlockItemSyntax.self) == true
            }
            node = parent
        }
        return false
    }

    /// 操作ごとの、同じ名前の引数 (操作の表の `IntrospectionAction(…)` に渡した引数の名前が重なるもの)。
    /// 引数を表の中の名前 (`let <名前> = ActionParameter<…>.<作り方>("<引数の名前>", …)`) で渡したときは、その名前から引数の名前を探す
    public static func duplicateParameterNames(in file: SourceFile) -> [Finding] {
        file.nodes.compactMap { $0.as(PatternBindingSyntax.self) }
            .filter { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "introspectionTable" }
            .flatMap { table -> [Finding] in
                let nodes = table.descendants()
                // 表の中で名前を付けた引数
                var named: [String: String] = [:]
                for binding in nodes.compactMap({ $0.as(PatternBindingSyntax.self) }) {
                    guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                        let value = binding.initializer?.value, let parameter = parameterName(value)
                    else { continue }
                    named[name] = parameter
                }
                return nodes.compactMap { $0.as(FunctionCallExprSyntax.self) }.compactMap { call in
                    guard call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "IntrospectionAction" else { return nil }
                    let parameters = call.arguments.dropFirst(2).filter { $0.label == nil && !$0.expression.is(ClosureExprSyntax.self) }
                        .compactMap { argument in
                            argument.expression.as(DeclReferenceExprSyntax.self).flatMap { named[$0.baseName.text] }
                                ?? parameterName(argument.expression)
                        }
                    return Set(parameters).count == parameters.count ? nil : Finding(file, call)
                }
            }
    }

    /// 引数の作り方 (`.<作り方>("<名前>", …)`。`.optional` などを付けても) に渡した名前
    private static func parameterName(_ expression: ExprSyntax) -> String? {
        expression.descendants().lazy.compactMap { $0.as(FunctionCallExprSyntax.self) }
            .compactMap { $0.arguments.first?.expression.as(StringLiteralExprSyntax.self)?.segments.trimmedDescription }
            .first
    }
}
