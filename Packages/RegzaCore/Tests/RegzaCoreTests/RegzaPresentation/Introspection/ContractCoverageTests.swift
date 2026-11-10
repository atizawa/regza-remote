import Foundation
import Testing

/// 約束事 (CLI と振る舞いのテストの操作) に漏れがないことを確かめる。
/// 画面の Action (ViewModels/<画面>/Action/) のどの case も、操作を Action にする処理 (画面の ViewModel の action(_:_:)、
/// 部品の ViewModel の introspectionAction(_:_:)) で作られていること (アプリの画面から送れる操作は、どれも約束事からも送れる)
@Suite struct ContractCoverageTests {
    static let viewModels = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(path: "../../../../Sources/RegzaPresentation/ViewModels").standardized

    /// Action の型の case
    struct ActionType {
        var name: String
        var cases: [String]
        var file: URL
    }

    static func actionTypes() throws -> [ActionType] {
        let files = try FileManager.default.subpathsOfDirectory(atPath: viewModels.path(percentEncoded: false))
            .filter { $0.contains("/Action/") && $0.hasSuffix(".swift") }
            .map { viewModels.appending(path: $0) }
        return try files.map { file in
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            let name = try #require(
                lines.lazy.compactMap { $0.firstMatch(of: /^public enum (\w+)/)?.1 }.first.map(String.init),
                "\(file.lastPathComponent) に public enum がありません")
            let cases = lines.compactMap { line in
                line.trimmingCharacters(in: .whitespaces).firstMatch(of: /^case (\w+)/).map { String($0.1) }
            }
            return ActionType(name: name, cases: cases, file: file)
        }
    }

    /// 型を作る処理 (action(_:_:) か introspectionAction(_:_:)) の中身
    static func decoder(of action: ActionType) throws -> String? {
        let files = try FileManager.default.subpathsOfDirectory(atPath: viewModels.path(percentEncoded: false))
            .filter { !$0.contains("/Action/") && !$0.contains("/State/") && $0.hasSuffix(".swift") }
            .map { viewModels.appending(path: $0) }
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let signature: String
            if text.contains("typealias Action = \(action.name)\n"), let range = text.range(of: "func action(_ name: String") {
                signature = String(text[range.lowerBound...])
            } else if let range = text.range(
                of: "func introspectionAction(_ name: String, _ arguments: [String: JSONValue]) throws -> \(action.name) {")
            {
                signature = String(text[range.lowerBound...])
            } else {
                continue
            }
            return body(signature)
        }
        return nil
    }

    /// 最初の { から、対になる } まで
    static func body(_ text: String) -> String {
        var depth = 0
        var started = false
        var result = ""
        for character in text {
            result.append(character)
            if character == "{" {
                depth += 1
                started = true
            }
            if character == "}" { depth -= 1 }
            if started && depth == 0 { break }
        }
        return result
    }

    @Test func everyActionCaseCanBeSentFromTheContract() throws {
        let types = try Self.actionTypes()
        #expect(types.count > 10, "Action の型が見つかりません: \(Self.viewModels.path(percentEncoded: false))")
        for type in types {
            #expect(!type.cases.isEmpty, "\(type.name) に case が見つかりません")
            let decoder = try #require(try Self.decoder(of: type), "\(type.name) を作る処理 (action(_:_:) か introspectionAction(_:_:)) が見つかりません")
            let missing = type.cases.filter { decoder.firstMatch(of: try! Regex("\\.\($0)\\b")) == nil }
            #expect(
                missing.isEmpty,
                "\(type.name) の \(missing.joined(separator: "・")) を約束事から送れません。操作を Action にする処理に足してください"
            )
        }
    }
}
