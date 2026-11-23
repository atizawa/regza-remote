import Foundation
import SwiftParser
import SwiftSyntax

/// 読んだ Swift のファイル 1 つ
public struct SourceFile {
    /// リポジトリからのパス
    public let path: String
    public let tree: SourceFileSyntax
    let converter: SourceLocationConverter

    public init(path: String, text: String) {
        self.path = path
        tree = Parser.parse(source: text)
        converter = SourceLocationConverter(fileName: path, tree: tree)
    }

    /// node の始まりの行 (1 から数える。前に付いたコメントや空白は除く)
    public func line(of node: some SyntaxProtocol) -> Int {
        converter.location(for: node.positionAfterSkippingLeadingTrivia).line
    }

    /// ファイルの中のすべての node (ソースの順)
    public var nodes: [Syntax] { Syntax(tree).descendants() }
}

/// 見張りが見つけた、決まりに合わないところ
public struct Finding: Equatable, CustomStringConvertible {
    /// リポジトリからのパス
    public var path: String
    /// 1 から数えた行の番号
    public var line: Int

    public init(path: String, line: Int) {
        self.path = path
        self.line = line
    }

    public init(_ file: SourceFile, _ node: some SyntaxProtocol) {
        self.init(path: file.path, line: file.line(of: node))
    }

    public var description: String { "\(path):\(line)" }
}

/// このリポジトリのソース
public enum Repository {
    /// リポジトリの root (この道具は Tools/SourceGuards/Sources/SourceGuards/ にある)
    public static let root = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// root からのパス (directory) の下の Swift のソースを、パスの順に読む。include で directory からのパスを選ぶ
    public static func files(under directory: String, include: (String) -> Bool = { _ in true }) throws -> [SourceFile] {
        let folder = root.appending(path: directory)
        return try FileManager.default.subpathsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".swift") && !$0.split(separator: "/").contains(".build") && include($0) }
            .sorted()
            .map { SourceFile(path: "\(directory)/\($0)", text: try String(contentsOf: folder.appending(path: $0), encoding: .utf8)) }
    }
}

extension SyntaxProtocol {
    /// 自分と、その下のすべての node (ソースの順)
    func descendants() -> [Syntax] {
        var result: [Syntax] = []
        func walk(_ node: Syntax) {
            result.append(node)
            for child in node.children(viewMode: .sourceAccurate) { walk(child) }
        }
        walk(Syntax(self))
        return result
    }
}
