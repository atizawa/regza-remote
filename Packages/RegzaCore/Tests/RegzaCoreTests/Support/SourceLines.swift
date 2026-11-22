import Foundation
import Testing

/// ソースを読む見張りのテストのための、コメントを除いたソースの行
struct SourceLine {
    /// 行を読み進めるときの、行をまたぐ状態
    enum Context: Equatable {
        case code
        /// /* */ の中。Swift は /* */ を入れ子にできるので、深さを数える
        case blockComment(depth: Int)
        /// 文字列の中。terminator で閉じる。生の文字列 (#" "#) では \ を特別に扱わない。1 行の文字列は行の終わりで閉じる
        case string(terminator: String, raw: Bool, multiline: Bool)
    }

    /// ファイルの終わりまでコメントや複数行の文字列が閉じなかった (読み違えて、後ろの行を見張れていない)
    struct UnclosedError: Error, CustomStringConvertible {
        var path: String
        var description: String { "\(path) のコメントか文字列が閉じていません。見張りが後ろの行を読めていません" }
    }

    /// 読んだ場所 (リポジトリからのパス)。問題を知らせるときに出す
    var root: String
    /// root からのパス
    var path: String
    /// 1 から数えた行の番号
    var number: Int
    /// コメント (// の後ろと /* */ の中) を除いた行
    var code: String

    /// 問題を知らせるときの場所 (リポジトリからのパスと行の番号)
    var location: String { "\(root)/\(path):\(number)" }

    /// リポジトリの root (からのパス) の下の Swift のソースを、パスの順に読む。include で root からのパスを選ぶ
    static func read(under root: String, include: (String) -> Bool = { _ in true }) throws -> [SourceLine] {
        let directory = FakeServersContractTests.repository.appending(path: root)
        let paths = try FileManager.default.subpathsOfDirectory(atPath: directory.path(percentEncoded: false))
            .filter { $0.hasSuffix(".swift") && include($0) }
            .sorted()
        return try paths.flatMap { path in
            var context = Context.code
            let lines = try String(contentsOf: directory.appending(path: path), encoding: .utf8).components(separatedBy: "\n")
                .enumerated()
                .map { index, line in
                    SourceLine(root: root, path: path, number: index + 1, code: stripComments(line, context: &context))
                }
            guard context == .code else { throw UnclosedError(path: "\(root)/\(path)") }
            return lines
        }
    }

    /// 行からコメントを除く。文字列 (""" と、# で囲んだ生の文字列を含む) の中の // や /* は、コメントとして扱わない
    static func stripComments(_ line: String, context: inout Context) -> String {
        var code = ""
        var index = line.startIndex
        func take(_ count: Int) {
            let end = line.index(index, offsetBy: count, limitedBy: line.endIndex) ?? line.endIndex
            code += line[index..<end]
            index = end
        }
        while index < line.endIndex {
            let rest = line[index...]
            switch context {
            case .blockComment(let depth):
                if rest.hasPrefix("*/") {
                    context = depth == 1 ? .code : .blockComment(depth: depth - 1)
                } else if rest.hasPrefix("/*") {
                    context = .blockComment(depth: depth + 1)
                }
                index = line.index(index, offsetBy: rest.hasPrefix("*/") || rest.hasPrefix("/*") ? 2 : 1)
            case .string(let terminator, let raw, _):
                if !raw, rest.hasPrefix("\\") {
                    take(2)
                } else if rest.hasPrefix(terminator) {
                    context = .code
                    take(terminator.count)
                } else {
                    take(1)
                }
            case .code:
                if rest.hasPrefix("//") { return code }
                if rest.hasPrefix("/*") {
                    context = .blockComment(depth: 1)
                    index = line.index(index, offsetBy: 2)
                    continue
                }
                // 文字列の始まり。# の数と """ かどうかで、閉じる印が決まる
                let hashes = rest.prefix { $0 == "#" }.count
                let quotes = rest.dropFirst(hashes)
                if quotes.hasPrefix("\"") {
                    let multiline = quotes.hasPrefix("\"\"\"")
                    let delimiter = multiline ? "\"\"\"" : "\""
                    context = .string(terminator: delimiter + String(repeating: "#", count: hashes), raw: hashes > 0, multiline: multiline)
                    take(hashes + delimiter.count)
                } else {
                    take(max(hashes, 1))
                }
            }
        }
        // 1 行の文字列は、行をまたがない
        if case .string(_, _, multiline: false) = context { context = .code }
        return code
    }
}

@Suite struct SourceLineTests {
    /// 行を順に読み、コメントを除いた行を返す
    static func strip(_ lines: [String]) -> [String] {
        var context = SourceLine.Context.code
        return lines.map { SourceLine.stripComments($0, context: &context) }
    }

    @Test func stripsLineAndBlockComments() {
        #expect(Self.strip(["a // b", "c /* d", "e */ f"]) == ["a ", "c ", " f"])
        #expect(Self.strip(["a /* b /* c */ d", "e */ f"]) == ["a ", " f"])
    }

    @Test func keepsCommentMarksInsideStrings() {
        #expect(Self.strip(["let a = \"x // \\\" /* y\" // z"]) == ["let a = \"x // \\\" /* y\" "])
        #expect(Self.strip(["let a = #\"\\\"# // z", "b"]) == ["let a = #\"\\\"# ", "b"])
        #expect(Self.strip(["let a = ##\"a\"# // b\"## // c"]) == ["let a = ##\"a\"# // b\"## "])
        let raw = Self.strip(["let a = #\"\"\"", "Sources/*.swift \"\"\" // x", "\"\"\"# // z", "b"])
        #expect(raw == ["let a = #\"\"\"", "Sources/*.swift \"\"\" // x", "\"\"\"# ", "b"])
        let multiline = Self.strip(["let a = \"\"\"", "Sources/*.swift // x", "\"\"\" // z", "b"])
        #expect(multiline == ["let a = \"\"\"", "Sources/*.swift // x", "\"\"\" ", "b"])
    }
}
