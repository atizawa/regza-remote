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
}
