public import Foundation

/// CLI の約束事 (1 行ずつの命令を受け取り、JSON を返す) の解釈と書き出し。
/// regza (iOS と同じ組み立て) と、振る舞いのテストの Android 側の相手が同じものを使い、命令の読み方と返す JSON の形をそろえる。
/// Android 側の相手は、操作を送るところと state を読むところだけを、アプリと同じ道 (Kotlin の send と xxxStates) に置き換える
///
///   tree                         ViewModel の道の一覧
///   ls [道]                      状態と操作の一覧 (道を省くと app)
///   do 道 操作 [JSON の引数]     操作して、通信などが終わるのを待ってから状態を返す
///   wait 秒                      待つ (定期の取得などを進める)
///   quit
@MainActor
public struct IntrospectionSession {
    public let introspector: Introspector

    public init(root: any Introspectable) {
        introspector = Introspector(root: root)
    }

    public enum Command: Equatable, Sendable {
        case tree
        case list(path: String)
        case perform(path: String, action: String, arguments: [String: JSONValue])
        case wait(seconds: Double)
        case quit
        /// 読めない命令 (返す JSON の説明)
        case invalid(String)
    }

    /// 1 行の命令を読む。空の行なら nil
    nonisolated public static func parse(_ line: String) -> Command? {
        let words = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true).map(String.init)
        guard let command = words.first else { return nil }
        let arguments = Array(words.dropFirst())
        switch command {
        case "tree": return .tree
        case "ls": return .list(path: arguments.first ?? "app")
        case "do":
            guard arguments.count >= 2 else { return .invalid("do 道 操作 [JSON の引数]") }
            guard arguments.count > 2 else { return .perform(path: arguments[0], action: arguments[1], arguments: [:]) }
            guard let value = try? JSONDecoder().decode(JSONValue.self, from: Data(arguments[2].utf8)), case .object(let object) = value else {
                return .invalid("引数は JSON のオブジェクトで渡す")
            }
            return .perform(path: arguments[0], action: arguments[1], arguments: object)
        case "wait": return .wait(seconds: arguments.first.flatMap(Double.init) ?? 1)
        case "quit": return .quit
        default: return .invalid("命令は tree・ls・do・wait・quit")
        }
    }

    /// 命令を動かして、返す JSON を作る (操作は ViewModel にそのまま送る。quit は空)
    public func run(_ command: Command) async -> String {
        switch command {
        case .tree: return JSONValue.array(introspector.paths().map(JSONValue.string)).json
        case .list(let path): return node(path)
        case .perform(let path, let action, let arguments):
            do {
                try introspector.perform(path, action, arguments)
            } catch {
                return Self.failure("\(error)")
            }
            return node(path, idle: await introspector.waitUntilIdle())
        case .wait(let seconds):
            try? await Task.sleep(for: .seconds(seconds))
            return #"{"waited":\#(seconds)}"#
        case .quit: return ""
        case .invalid(let message): return Self.failure(message)
        }
    }

    /// 道の状態と操作の一覧の JSON。state を渡せば、ViewModel から読む代わりにそれを使う
    /// (Android 側の相手が、アプリと同じ道で受け取った state を渡す)
    public func node(_ path: String, state: JSONValue? = nil, idle: Bool = true) -> String {
        do {
            var node = try introspector.node(path)
            if let state { node.state = state }
            if !idle { node.isBusy = true }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(node), as: UTF8.self)
        } catch {
            return Self.failure("\(error)")
        }
    }

    /// 道の ViewModel で、名前と引数の操作を Action にする (送らない)。できない操作なら投げる
    public func action(_ path: String, _ name: String, _ arguments: [String: JSONValue]) throws -> Any {
        let target = try introspector.find(path).introspectionTarget
        guard let viewModel = target as? any IntrospectableActions else { throw IntrospectionError.unknownAction(name) }
        return try Self.action(of: viewModel, name, arguments)
    }

    private static func action(of viewModel: some IntrospectableActions, _ name: String, _ arguments: [String: JSONValue]) throws -> Any {
        try viewModel.action(name, arguments)
    }

    nonisolated public static func failure(_ message: String) -> String {
        JSONValue.object(["error": .string(message)]).json
    }
}
