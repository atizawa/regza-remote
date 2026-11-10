import Foundation
import SwiftParser
import SwiftSyntax

/// つなぎを作れないとき (State/・Action/ の置き方が決まりに合わないとき) の説明
public struct ScreenGlueError: Error, CustomStringConvertible {
    public let description: String

    init(_ description: String) {
        self.description = description
    }
}

/// swift-java の設定に書く、ほかのモジュールの型 (importedModuleStubs の 1 つ)
struct TypeStub: Equatable {
    /// struct・enum
    var kind: String
    var name: String
    /// raw value が String の enum (swift-java に、そのことも書く)
    var isStringEnum: Bool

    /// 設定に書く形 ("public enum <名前>: String {}" など)
    var text: String { "public \(kind) \(name)\(isStringEnum ? ": String" : "") {}" }
}

/// 窓口から送り先と state を作る画面 (「typealias Action = 型」を書いた ViewModel)
struct Screen: Equatable {
    var viewModel: String
    var action: String
    var state: String
    /// 約束事 (CLI と振る舞いのテスト) の操作を Action にできる (IntrospectableActions)
    var isIntrospectable: Bool
}

/// 読んだ State/ と Action/ の型と、画面
struct Sources {
    /// State/ と Action/ の型 (窓口の設定の "RegzaPresentation" に書く。State/ が先、それぞれパスの順)
    var presentationStubs: [TypeStub] = []
    /// RegzaSharedModels の型 (設定の "RegzaSharedModels" に書く)
    var sharedStubs: [TypeStub] = []
    /// Action/ のパスの順
    var screens: [Screen] = []

    /// - Parameters:
    ///   - viewModels: RegzaPresentation/ViewModels
    ///   - sharedModels: RegzaSharedModels のソース
    init(viewModels: URL, sharedModels: URL) throws {
        let files = try Self.swiftFiles(in: viewModels)
        for file in files where file.pathComponents.contains("State") {
            let source = try SwiftFile(file)
            try source.requireTypedProperties()
            presentationStubs.append(try source.onlyType(kinds: ["struct", "enum"]))
        }
        for file in files where file.pathComponents.contains("Action") {
            let source = try SwiftFile(file)
            let action = try source.onlyType(kinds: ["enum"])
            presentationStubs.append(action)
            if let screen = try Self.screen(for: action.name, file: file) {
                screens.append(screen)
            }
        }
        for file in try Self.swiftFiles(in: sharedModels) {
            sharedStubs += try SwiftFile(file).publicTypes(kinds: ["struct", "enum"])
        }
    }

    /// フォルダの下の .swift (パスの順)
    static func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            throw ScreenGlueError("\(directory.path) を読めません")
        }
        return enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .map(\.standardizedFileURL)
            .sorted { $0.path < $1.path }
    }

    /// Action の型を送り先にしている画面。ほかの Action の中で使う部品の操作なら nil (送る関数は作らない)
    static func screen(for action: String, file: URL) throws -> Screen? {
        // Action/ のあるフォルダの ViewModel のうち、この型を Action にしているもの
        let screenDirectory = file.deletingLastPathComponent().deletingLastPathComponent()
        let candidates = try FileManager.default.contentsOfDirectory(at: screenDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
            .map(SwiftFile.init)
        let viewModelFiles = candidates.filter { $0.typeAlias("Action") == action }
        guard let viewModelFile = viewModelFiles.first else {
            // 同じフォルダのほかの Action の部品なら、送る関数は作らない
            let otherActions = try FileManager.default.contentsOfDirectory(
                at: screenDirectory.appending(path: "Action"), includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "swift" && $0.standardizedFileURL != file.standardizedFileURL }
            .map(SwiftFile.init)
            guard otherActions.contains(where: { $0.usesAsAssociatedValue(action) }) else {
                throw ScreenGlueError(
                    "\(file.path) の \(action) を Action にしている ViewModel (「typealias Action = \(action)」) も、"
                        + "使っている Action も \(screenDirectory.path) にありません"
                )
            }
            return nil
        }
        guard viewModelFiles.count == 1 else {
            throw ScreenGlueError("\(screenDirectory.path) に「typealias Action = \(action)」と書いた ViewModel を 1 つだけ置いてください")
        }
        let viewModel = try viewModelFile.onlyType(kinds: ["final class"]).name
        guard let state = viewModelFile.typeAlias("State") else {
            throw ScreenGlueError("\(viewModelFile.url.path) に「public typealias State = 型」を書いてください")
        }
        return Screen(
            viewModel: viewModel, action: action, state: state,
            isIntrospectable: viewModelFile.conforms(to: "IntrospectableActions")
        )
    }
}

/// swift-syntax で読んだ 1 つの Swift のファイル
struct SwiftFile {
    let url: URL
    let syntax: SourceFileSyntax

    init(_ url: URL) throws {
        self.url = url
        syntax = Parser.parse(source: try String(contentsOf: url, encoding: .utf8))
    }

    /// ファイルのいちばん外の public な型 (kinds は "struct"・"enum"・"final class")
    func publicTypes(kinds: Set<String>) -> [TypeStub] {
        syntax.statements.compactMap { item -> TypeStub? in
            let declaration = item.item
            if let type = declaration.as(StructDeclSyntax.self), kinds.contains("struct"), type.modifiers.contains(.public) {
                return TypeStub(kind: "struct", name: type.name.text, isStringEnum: false)
            }
            if let type = declaration.as(EnumDeclSyntax.self), kinds.contains("enum"), type.modifiers.contains(.public) {
                let firstInherited = type.inheritanceClause?.inheritedTypes.first?.type.trimmedDescription
                return TypeStub(kind: "enum", name: type.name.text, isStringEnum: firstInherited == "String")
            }
            if let type = declaration.as(ClassDeclSyntax.self), kinds.contains("final class"),
                type.modifiers.contains(.public), type.modifiers.contains(.final)
            {
                return TypeStub(kind: "final class", name: type.name.text, isStringEnum: false)
            }
            return nil
        }
    }

    /// ファイルに 1 つだけ置いた public な型
    func onlyType(kinds: Set<String>) throws -> TypeStub {
        let types = publicTypes(kinds: kinds)
        guard types.count == 1, let type = types.first else {
            throw ScreenGlueError("\(url.path) には public \(kinds.sorted().joined(separator: "・")) を 1 つだけ置いてください")
        }
        return type
    }

    /// swift-java は型を書いていないプロパティ (public var count = 0 など) を黙って飛ばすので、型を書いてもらう
    func requireTypedProperties() throws {
        let untyped = UntypedProperties(file: self).found
        guard untyped.isEmpty else {
            throw ScreenGlueError("\(url.path) のプロパティに型を書いてください (swift-java が飛ばします): \(untyped.joined(separator: "、"))")
        }
    }

    /// 「typealias 名前 = 型」の型
    func typeAlias(_ name: String) -> String? {
        TypeAliases(file: self).values[name]
    }

    /// 型や extension が protocol に準拠している
    func conforms(to protocolName: String) -> Bool {
        Conformances(file: self).names.contains(protocolName)
    }

    /// enum の case の値に、その型を使っている (部品の操作を、画面の Action の case に入れている)
    func usesAsAssociatedValue(_ type: String) -> Bool {
        AssociatedValues(file: self).types.contains(type)
    }
}

extension DeclModifierListSyntax {
    func contains(_ keyword: Keyword) -> Bool {
        contains { $0.name.tokenKind == .keyword(keyword) }
    }
}

/// 型を書かずに値で決めている public なプロパティ ("行: 書いたもの")
private final class UntypedProperties: SyntaxVisitor {
    private(set) var found: [String] = []
    private let converter: SourceLocationConverter

    init(file: SwiftFile) {
        converter = SourceLocationConverter(fileName: file.url.path, tree: file.syntax)
        super.init(viewMode: .sourceAccurate)
        walk(file.syntax)
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.modifiers.contains(.public),
            node.bindings.contains(where: { $0.typeAnnotation == nil && $0.initializer != nil })
        {
            let line = node.startLocation(converter: converter).line
            found.append("\(line) 行目「\(node.trimmedDescription)」")
        }
        return .skipChildren
    }
}

/// typealias の名前と型
private final class TypeAliases: SyntaxVisitor {
    private(set) var values: [String: String] = [:]

    init(file: SwiftFile) {
        super.init(viewMode: .sourceAccurate)
        walk(file.syntax)
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        values[node.name.text] = node.initializer.value.trimmedDescription
        return .skipChildren
    }
}

/// 型と extension が準拠している protocol の名前
private final class Conformances: SyntaxVisitor {
    private(set) var names: Set<String> = []

    init(file: SwiftFile) {
        super.init(viewMode: .sourceAccurate)
        walk(file.syntax)
    }

    override func visit(_ node: InheritanceClauseSyntax) -> SyntaxVisitorContinueKind {
        names.formUnion(node.inheritedTypes.map(\.type.trimmedDescription))
        return .skipChildren
    }
}

/// enum の case の値の型
private final class AssociatedValues: SyntaxVisitor {
    private(set) var types: Set<String> = []

    init(file: SwiftFile) {
        super.init(viewMode: .sourceAccurate)
        walk(file.syntax)
    }

    override func visit(_ node: EnumCaseParameterSyntax) -> SyntaxVisitorContinueKind {
        types.insert(node.type.trimmedDescription)
        return .skipChildren
    }
}
