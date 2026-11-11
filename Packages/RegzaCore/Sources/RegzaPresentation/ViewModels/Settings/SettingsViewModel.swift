public import Foundation
public import Observation
package import RegzaDomain

/// 設定の画面の ViewModel。テレビの登録 (TVSetupViewModel) と録画サーバー (ServerSetupViewModel) を部品に持ち、
/// 設定の中の画面の移り変わりと、保存・閉じるを受け持つ
@MainActor
@Observable
public final class SettingsViewModel {
    public let remoteViewModel: RemoteViewModel
    let tvSetupViewModel: TVSetupViewModel
    let serverSetupViewModel: ServerSetupViewModel
    /// 設定を閉じる (AppViewModel が渡す)
    @ObservationIgnored private let close: @MainActor () -> Void

    package init(remoteViewModel: RemoteViewModel, setupUseCase: any SetupUseCaseProtocol, close: @escaping @MainActor () -> Void) {
        self.remoteViewModel = remoteViewModel
        tvSetupViewModel = TVSetupViewModel(remoteViewModel: remoteViewModel, setupUseCase: setupUseCase)
        serverSetupViewModel = ServerSetupViewModel(setupUseCase: setupUseCase)
        self.close = close
        // テレビが未設定なら、テレビの設定の画面から始める
        path = remoteViewModel.connection.isConfigured ? [] : [.tv]
    }

    /// 画面に出すもの
    public typealias State = SettingsState

    /// 画面からの操作
    public typealias Action = SettingsAction

    private var path: [SettingsPage]
    @ObservationIgnored private let work = Work()

    public var state: State {
        let tv = tvSetupViewModel.state
        let servers = serverSetupViewModel.state
        return State(
            path: path,
            canClose: remoteViewModel.state.isConfigured,
            canSave: tv.canSave && servers.isValid,
            tv: tv,
            servers: servers
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .setPath(let path): open(path)
        case .openPage(let page): open(path + [page])
        case .back: open(path.dropLast())
        case .save:
            work.run {
                await self.serverSetupViewModel.save()
                await self.tvSetupViewModel.save()
                self.close()
            }
        case .close: close()
        case .tv(.confirmPairing):
            // PIN で登録できたら (保存も済んでいる) 閉じる
            work.run {
                await self.tvSetupViewModel.confirmPairing()
                if self.tvSetupViewModel.state.hasRegistered { self.close() }
            }
        case .tv(let action): tvSetupViewModel.send(action)
        case .server(let action):
            serverSetupViewModel.send(action)
            // 連携を解除したら、その設定の画面を閉じる
            if case .unlink(let server) = action { path.removeAll { $0 == SettingsPage(server) } }
        }
    }

    private func open(_ newPath: [SettingsPage]) {
        // ライブ視聴の設定を開いたら、Mirakurun と同じサーバーで EPGStation が動いていれば候補に出す
        if newPath.last == .stream, path.last != .stream { serverSetupViewModel.send(.suggestStreamHost) }
        path = newPath
    }

    /// 画面を閉じた。PIN を入れずに閉じたら、テレビの PIN 表示を消しておく (AppViewModel が呼ぶ)
    func dismiss() {
        tvSetupViewModel.send(.close)
    }
}

extension SettingsPage {
    /// 録画サーバーの設定の画面
    fileprivate init(_ server: ServerSetupServer) {
        self = server == .guide ? .guide : .stream
    }
}

extension SettingsViewModel: IntrospectableActions {
    public var introspectionName: String { "settings" }
    public var isBusy: Bool { work.isBusy || tvSetupViewModel.isBusy || serverSetupViewModel.isBusy }

    /// パスワードは見せない (入っているかどうかだけ)
    nonisolated public static func introspectionJSON(of state: State) -> JSONValue {
        var state = state
        if !state.tv.password.isEmpty { state.tv.password = "(入力済み)" }
        return JSONValue(reflecting: state)
    }

    /// 設定の画面の操作と、部品の操作 (テレビの登録は「tv.〜」、録画サーバーは「server.〜」)
    public var introspectionActions: [ActionDescription] {
        func prefixed(_ prefix: String, _ actions: [ActionDescription]) -> [ActionDescription] {
            actions.map { ActionDescription(prefix + $0.name, $0.summary, parameters: $0.parameters) }
        }
        return [
            ActionDescription("openPage", "設定の中の画面を開く", parameters: ["page": "tv | guide | stream"]),
            ActionDescription("back", "設定の中で 1 つ戻る"),
            ActionDescription("setPath", "設定の中の画面の並びをまとめて変える (iOS で戻るスワイプをしたときと同じ)", parameters: ["path": "[tv | guide | stream]"]),
            ActionDescription("save", "設定を保存して閉じる"),
            ActionDescription("close", "設定を閉じる (保存しない)"),
        ] + prefixed("tv.", TVSetupViewModel.introspectionActions) + prefixed("server.", ServerSetupViewModel.introspectionActions)
    }

    public func action(_ name: String, _ arguments: [String: JSONValue]) throws -> Action {
        if name.hasPrefix("tv.") { return .tv(try tvSetupViewModel.introspectionAction(String(name.dropFirst(3)), arguments)) }
        if name.hasPrefix("server.") { return .server(try serverSetupViewModel.introspectionAction(String(name.dropFirst(7)), arguments)) }
        switch name {
        case "openPage":
            guard let page = SettingsPage(rawValue: try arguments.string("page")) else { throw IntrospectionError.invalidArgument("page") }
            return .openPage(page)
        case "back": return .back
        case "setPath":
            guard case .array(let pages) = arguments["path"] ?? .array([]) else { throw IntrospectionError.invalidArgument("path") }
            return .setPath(
                try pages.map { page in
                    guard case .string(let name) = page, let page = SettingsPage(rawValue: name) else {
                        throw IntrospectionError.invalidArgument("path")
                    }
                    return page
                })
        case "save": return .save
        case "close": return .close
        default: throw IntrospectionError.unknownAction(name)
        }
    }
}
