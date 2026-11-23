import Foundation
public import Observation
public import PresentationCore
package import RegzaDomain
import RegzaStrings

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
    @ObservationIgnored private let onAppearanceChange: @MainActor (AppAppearance) -> Void
    private var appearance: AppAppearance

    package init(
        remoteViewModel: RemoteViewModel, setupUseCase: any SetupUseCaseProtocol,
        appearance: AppAppearance = .system,
        onAppearanceChange: @escaping @MainActor (AppAppearance) -> Void = { _ in },
        close: @escaping @MainActor () -> Void
    ) {
        self.remoteViewModel = remoteViewModel
        tvSetupViewModel = TVSetupViewModel(remoteViewModel: remoteViewModel, setupUseCase: setupUseCase)
        serverSetupViewModel = ServerSetupViewModel(setupUseCase: setupUseCase)
        self.close = close
        self.appearance = appearance
        self.onAppearanceChange = onAppearanceChange
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
            appearance: appearance,
            path: path,
            canSave: tv.canSave && servers.isValid,
            tv: tv,
            servers: servers
        )
    }

    public func send(_ action: Action) {
        switch action {
        case .setAppearance(let appearance):
            guard self.appearance != appearance else { return }
            self.appearance = appearance
            onAppearanceChange(appearance)
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

    package var restorationState: SettingsRestorationState {
        let state = state
        return SettingsRestorationState(
            path: path, host: state.tv.host, user: state.tv.user, isShowingManualEntry: state.tv.isShowingManualEntry,
            guideHost: state.servers.guide.host, streamHost: state.servers.stream.host)
    }

    package func restore(_ saved: SettingsRestorationState) {
        // 保存済みパスワードは初期値を使い、PIN 登録や探索などの処理は再開しない。
        tvSetupViewModel.send(.setHost(saved.host))
        tvSetupViewModel.send(.setUser(saved.user))
        tvSetupViewModel.send(.setShowingManualEntry(saved.isShowingManualEntry))
        serverSetupViewModel.send(.setHost(.guide, saved.guideHost))
        serverSetupViewModel.send(.setHost(.stream, saved.streamHost))
        path = saved.path
    }

    /// 画面を閉じた。PIN を入れずに閉じたら、テレビの PIN 表示を消しておく (AppViewModel が呼ぶ)
    package func dismiss() {
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
        if !state.tv.password.isEmpty { state.tv.password = CoreStrings.settingsPasswordEntered }
        return JSONValue(reflecting: state)
    }

    /// 設定の画面の操作と、部品の操作 (テレビの登録は「tv.〜」、録画サーバーは「server.〜」)
    public var introspectionTable: [IntrospectionAction<Action>] {
        [
            IntrospectionAction("setAppearance", "外観を保存して切り替える", ActionParameter<AppAppearance>.choice("appearance")) {
                .setAppearance($0)
            },
            IntrospectionAction("openPage", "設定の中の画面を開く", ActionParameter<SettingsPage>.choice("page")) { .openPage($0) },
            IntrospectionAction("back", "設定の中で 1 つ戻る", .back),
            IntrospectionAction(
                "setPath", "設定の中の画面の並びをまとめて変える (iOS で戻るスワイプをしたときと同じ)",
                .array("path", "[\(SettingsPage.allCases.map(\.rawValue).joined(separator: " | "))]")
            ) { pages in
                .setPath(
                    try pages.map { page in
                        guard case .string(let name) = page, let page = SettingsPage(rawValue: name) else {
                            throw IntrospectionError.invalidArgument("path")
                        }
                        return page
                    })
            },
            IntrospectionAction("save", "設定を保存して閉じる", .save),
            IntrospectionAction("close", "設定を閉じる (保存しない)", .close),
        ]
            + tvSetupViewModel.introspectionTable.map { $0.prefixed("tv.") { .tv($0) } }
            + serverSetupViewModel.introspectionTable.map { $0.prefixed("server.") { .server($0) } }
    }
}
