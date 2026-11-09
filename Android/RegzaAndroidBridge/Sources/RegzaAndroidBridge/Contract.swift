import Foundation
import RegzaApp

// 振る舞いのテスト (BehaviorTests) の Android 側の相手が使う、約束事 (regza と同じ 1 行ずつの命令) の口。
// 命令の読み方と返す JSON の形は regza と同じもの (IntrospectionSession) を使い、
// 操作を送るところと state を読むところだけを、Kotlin がアプリと同じ道 (send と xxxStates) で行う。
// 型ごとの口 (contractChannelListAction・contractChannelListStateJSON など) は scripts/generate-screen-glue.sh が作る

/// 読んだ 1 行の命令
public struct RegzaContractCommand {
    /// "do"・"ls"・"quit"、それ以外 (tree・wait・読めない命令) は "other"
    public var kind: String
    public var path: String
    public var action: String
    /// 引数の JSON のオブジェクト
    public var arguments: String
}

extension RegzaAndroidApp {
    @MainActor private var session: IntrospectionSession { IntrospectionSession(root: app) }

    /// 1 行の命令を読む。空の行なら nil
    public func contractParse(line: String) async -> RegzaContractCommand? {
        guard let command = IntrospectionSession.parse(line) else { return nil }
        return switch command {
        case .perform(let path, let action, let arguments):
            RegzaContractCommand(kind: "do", path: path, action: action, arguments: JSONValue.object(arguments).json)
        case .list(let path): RegzaContractCommand(kind: "ls", path: path, action: "", arguments: "{}")
        case .quit: RegzaContractCommand(kind: "quit", path: "", action: "", arguments: "{}")
        default: RegzaContractCommand(kind: "other", path: "", action: "", arguments: "{}")
        }
    }

    /// do・ls 以外の命令 (tree・wait・読めない命令) を regza と同じく動かして、返す JSON
    public func contractRun(line: String) async -> String {
        guard let command = IntrospectionSession.parse(line) else { return "" }
        return await session.run(command)
    }

    /// 操作を Action にできなければ、regza と同じ失敗の JSON。できれば nil
    public func contractCheck(path: String, action: String, arguments: String) async -> String? {
        await MainActor.run {
            do {
                _ = try contractAction(path: path, action: action, arguments: arguments)
                return nil
            } catch {
                return IntrospectionSession.failure("\(error)")
            }
        }
    }

    /// 道の ViewModel の型の名前 (ChannelListViewModel など)。道がなければ nil
    public func contractTargetType(path: String) async -> String? {
        await MainActor.run {
            (try? session.introspector.find(path).introspectionTarget).map { String(describing: type(of: $0)) }
        }
    }

    /// 道の ViewModel が、タブの path に積んだ画面なら、その画面 (xxxState(route:) で引くため)
    public func contractTargetRoute(path: String) async -> AppRoute? {
        await MainActor.run {
            guard let target = try? session.introspector.find(path).introspectionTarget else { return nil }
            let routes = AppTab.allCases.flatMap { app.state.path(of: $0) }
            return routes.first { app.viewModel(for: $0) === target }
        }
    }

    /// 送った操作の通信などが終わるまで待つ (regza の do と同じ)。待ちきれなければ false
    public func contractWaitUntilIdle() async -> Bool {
        await session.introspector.waitUntilIdle()
    }

    /// 操作のあと、その道の ViewModel がなくなった (閉じた) ときに返す JSON (regza の do と同じ)。まだあれば nil
    public func contractClosed(path: String) async -> String? {
        await MainActor.run { (try? session.introspector.find(path)) == nil ? IntrospectionSession.closed(path) : nil }
    }

    /// 道の状態と操作の一覧の JSON (regza の ls と同じ形)。state は Kotlin がアプリと同じ道で受け取ったものを使う
    public func contractNode(path: String, stateJSON: String, idle: Bool) async -> String {
        let state = try? JSONDecoder().decode(JSONValue.self, from: Data(stateJSON.utf8))
        return await MainActor.run { session.node(path, state: state, idle: idle) }
    }

    /// 道の ViewModel で、名前と引数の操作を Action にする (送らない)
    @MainActor func contractAction(path: String, action: String, arguments: String) throws -> Any {
        guard case .object(let object) = try JSONDecoder().decode(JSONValue.self, from: Data(arguments.utf8)) else {
            throw IntrospectionError.invalidArgument("arguments")
        }
        return try session.action(path, action, object)
    }
}
