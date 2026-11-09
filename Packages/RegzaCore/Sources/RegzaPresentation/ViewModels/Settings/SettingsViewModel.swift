public import Foundation
public import Observation
package import RegzaDomain

/// 設定の画面の ViewModel。テレビの登録 (TVSetupViewModel) と録画サーバー (ServerSetupViewModel) を部品に持ち、
/// 設定の中の画面の移り変わりと、保存・閉じるを受け持つ
@MainActor
@Observable
public final class SettingsViewModel {
    public let remote: RemoteViewModel
    let tv: TVSetupViewModel
    let servers: ServerSetupViewModel
    /// 設定を閉じる (AppViewModel が渡す)
    @ObservationIgnored private let close: @MainActor () -> Void

    package init(remote: RemoteViewModel, setup: any SetupUseCaseProtocol, close: @escaping @MainActor () -> Void) {
        self.remote = remote
        tv = TVSetupViewModel(remote: remote, setup: setup)
        servers = ServerSetupViewModel(setup: setup)
        self.close = close
        // テレビが未設定なら、テレビの設定の画面から始める
        path = remote.connection.isConfigured ? [] : [.tv]
        tv.forward = { [weak self] in self?.send(.tv($0)) }
        servers.forward = { [weak self] in self?.send(.server($0)) }
    }

    /// 画面に出すもの
    public typealias State = SettingsState

    /// 画面からの操作
    public typealias Action = SettingsAction

    private var path: [SettingsPage]
    @ObservationIgnored private let work = Work()

    public var state: State {
        let tv = tv.state
        let servers = servers.state
        return State(
            path: path,
            canClose: remote.state.isConfigured,
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
                await self.servers.save()
                await self.tv.save()
                self.close()
            }
        case .close: close()
        case .tv(.confirmPairing):
            // PIN で登録できたら (保存も済んでいる) 閉じる
            work.run {
                await self.tv.confirmPairing()
                if self.tv.state.hasRegistered { self.close() }
            }
        case .tv(let action): tv.send(action)
        case .server(let action):
            servers.send(action)
            // 連携を解除したら、その設定の画面を閉じる
            if case .unlink(let server) = action { path.removeAll { $0 == SettingsPage(server) } }
        }
    }

    private func open(_ newPath: [SettingsPage]) {
        // ライブ視聴の設定を開いたら、Mirakurun と同じサーバーで EPGStation が動いていれば候補に出す
        if newPath.last == .stream, path.last != .stream { servers.send(.suggestStreamHost) }
        path = newPath
    }

    /// 画面を閉じた。PIN を入れずに閉じたら、テレビの PIN 表示を消しておく (AppViewModel が呼ぶ)
    func dismiss() {
        tv.send(.close)
    }
}

private extension SettingsPage {
    /// 録画サーバーの設定の画面
    init(_ server: ServerSetupServer) {
        self = server == .guide ? .guide : .stream
    }
}

extension SettingsViewModel: Introspectable {
    public var introspectionName: String { "settings" }
    public var introspectionValue: Any { state.path }
    public var isBusy: Bool { work.isBusy }
    public var introspectionChildren: [any Introspectable] { [tv, servers] }

    public var introspectionActions: [ActionDescription] {
        [
            ActionDescription("openPage", "設定の中の画面を開く", parameters: ["page": "tv | guide | stream"]),
            ActionDescription("save", "設定を保存して閉じる"),
            ActionDescription("close", "設定を閉じる (保存しない)"),
        ]
    }

    public func perform(_ action: String, _ arguments: [String: JSONValue]) throws {
        switch action {
        case "openPage":
            guard let page = SettingsPage(rawValue: try arguments.string("page")) else { throw IntrospectionError.invalidArgument("page") }
            send(.openPage(page))
        case "save": send(.save)
        case "close": send(.close)
        default: throw IntrospectionError.unknownAction(action)
        }
    }
}
