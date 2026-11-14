#if os(iOS)
import Localization
import RegzaPresentation
import SwiftUI

struct SettingsScreen: View {
    @State private var settingsViewModel: SettingsViewModel
    @FocusState private var isPINFocused: Bool
    /// 連携を解除するか確かめている設定
    @State private var unlinking: ServerSetupServer?

    init(settingsViewModel: SettingsViewModel) {
        _settingsViewModel = State(initialValue: settingsViewModel)
    }

    /// 設定の画面。テレビの設定と、録画サーバー (Mirakurun・EPGStation) の設定を別の画面に分ける
    private typealias Page = SettingsPage

    /// 開いている設定の画面 (テレビが未設定なら、SettingsViewModel がテレビの設定の画面から開く)
    private var path: Binding<[Page]> {
        Binding(get: { settingsViewModel.state.path }, set: { settingsViewModel.send(.setPath($0)) })
    }

    var body: some View {
        let state = settingsViewModel.state
        let tvState = state.tv
        let serverState = state.servers
        NavigationStack(path: path) {
            Form {
                Section(AppStrings.tvTitle) {
                    NavigationLink(value: Page.tv) {
                        LabeledContent("REGZA") {
                            Text(tvState.status.text)
                                .foregroundStyle(tvState.status.needsAttention ? Color.orange : .secondary)
                        }
                    }
                }

                Section(AppStrings.commonDisplay) {
                    appearancePicker
                    LiveActivityToggle()
                }

                Section {
                    NavigationLink(value: Page.guide) {
                        LabeledContent(AppStrings.settingsGuideIntegration, value: serverState.guide.status)
                    }
                    // EPGStation は Mirakurun から放送を受け取るので、Mirakurun を設定してから設定できるようにする
                    NavigationLink(value: Page.stream) {
                        LabeledContent(
                            AppStrings.settingsStreamIntegration,
                            value: serverState.hasGuideDraft ? serverState.stream.status : AppStrings.settingsGuideRequired)
                    }
                    .disabled(!serverState.hasGuideDraft)
                } header: {
                    Text(AppStrings.settingsRecordingServers)
                } footer: {
                    Text(
                        AppStrings.settingsServersHelp)
                }
            }
            .navigationTitle(AppStrings.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .tv:
                    tvPage
                case .guide:
                    serverPage(.guide, title: AppStrings.settingsGuideIntegration)
                case .stream:
                    serverPage(.stream, title: AppStrings.settingsStreamIntegration)
                }
            }
            // iOS 26 の標準に合わせ、キャンセルは ×、保存は ✓ (強調色) のボタンにする
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { settingsViewModel.send(.close) }
                        .accessibilityIdentifier("settings.close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    // 保存できたら SettingsViewModel が設定を閉じる
                    Button(role: .confirm) { settingsViewModel.send(.save) }
                        .disabled(!state.canSave)
                }
            }
            // テレビに PIN が出たら、すぐ打てるようにする
            .onChange(of: tvState.isWaitingForPIN) { _, isWaiting in
                if isWaiting { isPINFocused = true }
            }
        }
        .preferredColorScheme(state.appearance.preferredColorScheme)
    }

    private var appearancePicker: some View {
        let appearance = settingsViewModel.state.appearance
        let title =
            switch appearance {
            case .system: AppStrings.appearanceSystem
            case .light: AppStrings.appearanceLight
            case .dark: AppStrings.appearanceDark
            }
        return LabeledContent(AppStrings.appearanceTitle) {
            Menu {
                Picker(
                    AppStrings.appearanceTitle,
                    selection: Binding(get: { settingsViewModel.state.appearance }, set: { settingsViewModel.send(.setAppearance($0)) })
                ) {
                    Text(AppStrings.appearanceSystem).tag(AppAppearance.system)
                    Text(AppStrings.appearanceLight).tag(AppAppearance.light)
                    Text(AppStrings.appearanceDark).tag(AppAppearance.dark)
                }
                .pickerStyle(.inline)
            } label: {
                HStack {
                    // 全候補が収まる幅を確保し、選択を変えてもメニューの基準位置を保つ。
                    ZStack(alignment: .trailing) {
                        Text(AppStrings.appearanceSystem).hidden()
                        Text(AppStrings.appearanceLight).hidden()
                        Text(AppStrings.appearanceDark).hidden()
                    }
                    .overlay(alignment: .trailing) { Text(title) }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.tint)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.appearance")
        }
    }

    /// 入力欄を ViewModel につなぐ (打つたびに操作として送る)
    private func binding<Value>(_ value: Value, _ action: @escaping (Value) -> TVSetupAction) -> Binding<Value> {
        Binding(get: { value }, set: { settingsViewModel.send(.tv(action($0))) })
    }

    /// テレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
    private var tvPage: some View {
        let state = settingsViewModel.state.tv
        return Form {
            Section {
                TextField(AppStrings.tvHostPlaceholder, text: binding(state.host) { .setHost($0) })
                    .accessibilityIdentifier("settings.tv.host")
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(state.isWaitingForPIN)
                ForEach(state.devices) { row in
                    Button {
                        settingsViewModel.send(.tv(.select(row.host)))
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(row.name)
                                Text(row.host)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if row.isSelected {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .tint(.primary)
                    .disabled(state.isWaitingForPIN)
                }
                Button {
                    settingsViewModel.send(.tv(.scan))
                } label: {
                    HStack {
                        Label(state.isScanning ? AppStrings.tvSearching : AppStrings.tvSearch, systemImage: "magnifyingglass")
                        Spacer()
                        if state.isScanning { ProgressView() }
                    }
                }
                .disabled(state.isScanning || state.isWaitingForPIN)
                if let scanMessage = state.scanMessage {
                    Text(scanMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(AppStrings.tvTitle)
            } footer: {
                Text(AppStrings.tvNetworkHelpIos)
            }

            pairingSection(state)

            Section {
                DisclosureGroup(AppStrings.tvCredentials, isExpanded: binding(state.isShowingManualEntry) { .setShowingManualEntry($0) }) {
                    TextField(AppStrings.tvUsername, text: binding(state.user) { .setUser($0) })
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(AppStrings.tvPassword, text: binding(state.password) { .setPassword($0) })
                }
            } footer: {
                Text(AppStrings.tvLegacyHelp)
            }

            Section {
                Button {
                    settingsViewModel.send(.tv(.test))
                } label: {
                    HStack {
                        Text(AppStrings.tvTest)
                        Spacer()
                        if state.isTesting { ProgressView() }
                    }
                }
                .disabled(!state.hasAddress || state.isTesting)
                if let testResult = state.testResult {
                    Text(testResult)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("REGZA")
        .navigationBarTitleDisplayMode(.inline)
        // 未設定なら開いたときに探し始める
        .onAppear { settingsViewModel.send(.tv(.appear)) }
    }

    private func pairingSection(_ state: TVSetupState) -> some View {
        Section {
            if !state.isWaitingForPIN {
                Button {
                    settingsViewModel.send(.tv(.startPairing))
                } label: {
                    HStack {
                        Label(state.isRegistered ? AppStrings.tvRegisterAgain : AppStrings.tvShowPin, systemImage: "number.square")
                        Spacer()
                        if state.isPairing { ProgressView() }
                    }
                }
                .disabled(!state.hasAddress || state.isPairing)
            } else {
                TextField(AppStrings.tvPinPlaceholder, text: binding(state.pin) { .setPIN($0) })
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title3.monospacedDigit())
                    .focused($isPINFocused)
                Button {
                    settingsViewModel.send(.tv(.confirmPairing))
                } label: {
                    HStack {
                        Text(AppStrings.commonRegister)
                        Spacer()
                        if state.isPairing { ProgressView() }
                    }
                }
                .disabled(state.pin.isEmpty || state.isPairing)
                Button(AppStrings.commonCancel, role: .cancel) {
                    settingsViewModel.send(.tv(.cancelPairing))
                }
                .disabled(state.isPairing)
            }
            if let pairingMessage = state.pairingMessage {
                Text(pairingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(AppStrings.tvPinRegistration)
        } footer: {
            if !state.isWaitingForPIN {
                Text(AppStrings.tvPinStartHelp)
            } else {
                Text(AppStrings.tvPinInputHelp)
            }
        }
    }

    /// 録画サーバーの設定の画面。保存済みなら、連携を解除するボタンも出す
    private func serverPage(_ server: ServerSetupServer, title: String) -> some View {
        let state = settingsViewModel.state.servers[server]
        return Form {
            serverSection(server, state)
            if state.isLinked { unlinkSection(server, state) }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func serverSection(_ server: ServerSetupServer, _ state: ServerSetupServerState) -> some View {
        let name = server == .guide ? "Mirakurun" : "EPGStation"
        return Section {
            ServerAddressField(
                host: Binding(get: { state.host }, set: { settingsViewModel.send(.server(.setHost(server, $0))) }),
                defaultPort: state.defaultPort
            )
            ForEach(state.hosts, id: \.self) { host in
                Button {
                    settingsViewModel.send(.server(.setHost(server, host)))
                } label: {
                    HStack {
                        Text(host).monospacedDigit()
                        Spacer()
                        if state.host == host {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
            Button {
                settingsViewModel.send(.server(.scan(server)))
            } label: {
                HStack {
                    Label(
                        state.isScanning ? AppStrings.serverSearching(name) : AppStrings.serverSearch(name), systemImage: "magnifyingglass")
                    Spacer()
                    if state.isScanning { ProgressView() }
                }
            }
            .disabled(state.isScanning)
            if let message = state.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(server == .guide ? AppStrings.settingsGuideTitle : AppStrings.settingsStreamTitle)
        } footer: {
            Text(
                server == .guide
                    ? AppStrings.settingsGuideHelp
                    : AppStrings.settingsStreamHelpIos)
        }
    }

    /// 録画サーバーとの連携をやめる。確かめたうえで、すぐにアドレスを消して反映する
    private func unlinkSection(_ server: ServerSetupServer, _ state: ServerSetupServerState) -> some View {
        Section {
            Button(AppStrings.settingsUnlink, role: .destructive) { unlinking = server }
                .confirmationDialog(
                    state.unlinkTitle,
                    isPresented: Binding(get: { unlinking == server }, set: { if !$0 { unlinking = nil } }),
                    titleVisibility: .visible
                ) {
                    // SettingsViewModel が、その設定の画面を閉じる
                    Button(AppStrings.settingsUnlink, role: .destructive) { settingsViewModel.send(.server(.unlink(server))) }
                } message: {
                    Text(state.unlinkMessage)
                }
        }
    }
}

/// アドレスとポートを別々に入れる欄。ポートが空なら標準のポートを使う
private struct ServerAddressField: View {
    @Binding var host: String
    let defaultPort: Int

    private var address: Binding<String> {
        Binding(
            get: { ServerAddress(host).address },
            set: { host = ServerAddress(address: $0, port: ServerAddress(host).port).combined })
    }

    private var port: Binding<String> {
        Binding(
            get: { ServerAddress(host).port },
            set: { host = ServerAddress(address: ServerAddress(host).address, port: $0).combined })
    }

    var body: some View {
        HStack {
            TextField(AppStrings.serverHostPlaceholder, text: address)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Divider()
            // 標準のポートを薄く出し、空なら標準のポートを使う
            TextField(String(defaultPort), text: port)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .accessibilityLabel(AppStrings.serverPort)
        }
        if !ServerAddress(host).isValid {
            Text(AppStrings.serverPortHelp(defaultPort))
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }
}
#endif
