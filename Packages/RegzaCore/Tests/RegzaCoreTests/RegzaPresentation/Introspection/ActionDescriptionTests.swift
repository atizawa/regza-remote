import Foundation
import Testing

/// 操作の一覧 (introspectionActions の ActionDescription) が、操作を Action にする処理 (action(_:_:)・introspectionAction(_:_:)) と
/// 合っていることを、ソースを読んで確かめる。一覧に書いた操作の名前と引数の名前が、受け付ける名前と読む引数の名前と同じであること
/// (CLI と振る舞いのテストに見せる説明と、実際の動きが食い違わないように)
@Suite struct ActionDescriptionTests {
    /// 操作の名前 → 引数の名前
    typealias Table = [String: Set<String>]

    /// 1 つのファイルの、一覧に書いたものと、受け付けるもの
    struct Tables {
        var described: Table = [:]
        var accepted: Table = [:]
        var hasDescriptions = false
        var hasDecoder = false
    }

    /// コメントを除いたファイルの中身から、一覧と受け付けるものを読む
    static func tables(in code: String) -> Tables {
        var tables = Tables()
        for body in bodies(in: code, after: /var introspectionActions: \[ActionDescription\]/) {
            tables.hasDescriptions = true
            for call in calls(in: body, named: "ActionDescription(") {
                guard let name = call.firstMatch(of: /"([\w.]+)"/)?.1 else { continue }
                tables.described[String(name), default: []].formUnion(parameterNames(in: call))
            }
        }
        // 引数を読む部品 (func <名前>(_ arguments: [String: JSONValue]) か、処理の中の func <名前>()) が読む引数
        var helpers: [String: Set<String>] = [:]
        for match in code.matches(of: /func (\w+)\((?:_ arguments: \[String: JSONValue\])?\)/) {
            let rest = String(code[match.range.upperBound...])
            helpers[String(match.1)] = argumentNames(in: firstBody(rest), helpers: [:])
        }
        for body in bodies(in: code, after: /func (?:action|introspectionAction)\(_ name: String, _ arguments: \[String: JSONValue\]\)/) {
            tables.hasDecoder = true
            // case "名前": から、次の case か default までが、その操作の処理
            let labels = body.matches(of: /\n\s*case ((?:"[\w.]+"(?:,\s*)?)+):/)
            for (index, label) in labels.enumerated() {
                let end = index + 1 < labels.count ? labels[index + 1].range.lowerBound : body.endIndex
                let names = String(label.1).matches(of: /"([\w.]+)"/).map { String($0.1) }
                let arguments = argumentNames(in: String(body[label.range.upperBound..<end]), helpers: helpers)
                for name in names { tables.accepted[name, default: []].formUnion(arguments) }
            }
        }
        return tables
    }

    /// parameters: [ … ] のキー
    static func parameterNames(in call: String) -> Set<String> {
        guard let range = call.range(of: "parameters: [") else { return [] }
        return Set(call[range.upperBound...].matches(of: /"(\w+)"\s*:/).map { String($0.1) })
    }

    /// 処理が読む引数 (arguments.string("…") など、arguments["…"]、引数を読む部品の呼び出し (<名前>(arguments) か <名前>()))
    static func argumentNames(in text: String, helpers: [String: Set<String>]) -> Set<String> {
        var names = Set(text.matches(of: /arguments(?:\.(?:string|int|bool)\(|\[)"(\w+)"/).map { String($0.1) })
        for match in text.matches(of: /\b(\w+)\((?:arguments)?\)/) { names.formUnion(helpers[String(match.1)] ?? []) }
        return names
    }

    /// 印のあとの、最初の { から対になる } までを、印ごとに返す
    static func bodies(in code: String, after marker: Regex<some Any>) -> [String] {
        code.matches(of: marker).map { firstBody(String(code[$0.range.upperBound...])) }
    }

    /// 最初の { から、対になる } まで (文字列の中の括弧は数えない)
    static func firstBody(_ text: String) -> String {
        balanced(text, open: "{", close: "}")
    }

    /// 名前 (`ActionDescription(` など) の呼び出しを、対になる ) までずつ返す
    static func calls(in text: String, named name: String) -> [String] {
        text.ranges(of: name).map { balanced(String(text[$0.lowerBound...]), open: "(", close: ")") }
    }

    /// 最初の open から、対になる close まで。文字列 ("…") の中は数えない
    static func balanced(_ text: String, open: Character, close: Character) -> String {
        var depth = 0
        var inString = false
        var escaped = false
        var result = ""
        for character in text {
            result.append(character)
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }
            if character == "\"" {
                inString = true
            } else if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 { break }
            }
        }
        return result
    }

    /// 一覧と受け付けるもののずれ
    static func mismatches(_ tables: Tables) -> [String] {
        var problems: [String] = []
        for name in Set(tables.described.keys).subtracting(tables.accepted.keys).sorted() {
            problems.append("一覧の \(name) を受け付けていません")
        }
        for name in Set(tables.accepted.keys).subtracting(tables.described.keys).sorted() {
            problems.append("受け付ける \(name) が一覧にありません")
        }
        for (name, parameters) in tables.described.sorted(by: { $0.key < $1.key }) {
            guard let arguments = tables.accepted[name], arguments != parameters else { continue }
            let unread = parameters.subtracting(arguments).sorted()
            let undescribed = arguments.subtracting(parameters).sorted()
            if !unread.isEmpty { problems.append("\(name) の引数 \(unread.joined(separator: "・")) を一覧に書いていますが、読んでいません") }
            if !undescribed.isEmpty { problems.append("\(name) の引数 \(undescribed.joined(separator: "・")) を読んでいますが、一覧にありません") }
        }
        return problems
    }

    @Test func descriptionsMatchWhatIsAccepted() throws {
        let files = Dictionary(grouping: try SourceLine.read(under: "Packages/RegzaCore/Sources/Presentation"), by: \.path)
        var checked = 0
        for (path, lines) in files.sorted(by: { $0.key < $1.key }) {
            let tables = Self.tables(in: lines.map(\.code).joined(separator: "\n"))
            guard tables.hasDescriptions || tables.hasDecoder else { continue }
            let location = "Packages/RegzaCore/Sources/Presentation/\(path)"
            guard tables.hasDescriptions, tables.hasDecoder else {
                Issue.record("\(location) に、操作の一覧と、操作を Action にする処理の片方しかありません。同じファイルに書いてください")
                continue
            }
            checked += 1
            for problem in Self.mismatches(tables) { Issue.record("\(location): \(problem)") }
        }
        #expect(checked > 10, "操作の一覧が見つかりません")
    }

    /// 突き合わせが拾うずれを、作ったソースで確かめる
    @Test func findsMismatches() {
        let code = """
            public var introspectionActions: [ActionDescription] {
                [
                    ActionDescription("same", "同じ (括弧) {", parameters: ["a": "説明"]),
                    ActionDescription(
                        "helper", "部品で読む",
                        parameters: ["channel": "code", "page": "番号"]),
                    ActionDescription("unread", "読まない", parameters: ["b": "説明", "c": "説明"]),
                    ActionDescription("missing", "受け付けない"),
                ]
            }

            public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
                func page() throws -> Int { try arguments.int("page") }
                switch name {
                case "same": return .same(try arguments.string("a"))
                case "helper": return .helper(try channel(arguments), try page())
                case "unread": return .unread(try arguments.int("b"), arguments["d"] != nil)
                case "extra", "other": return .extra
                default: throw IntrospectionError.unknownAction(name)
                }
            }

            private func channel(_ arguments: [String: JSONValue]) throws -> String {
                try arguments.string("channel")
            }
            """
        #expect(
            Self.mismatches(Self.tables(in: code)) == [
                "一覧の missing を受け付けていません",
                "受け付ける extra が一覧にありません",
                "受け付ける other が一覧にありません",
                "unread の引数 c を一覧に書いていますが、読んでいません",
                "unread の引数 d を読んでいますが、一覧にありません",
            ])
    }
}
