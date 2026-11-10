#if os(iOS)
import RegzaPresentation
import SwiftUI

struct SettingsScreen: View {
    @State private var settings: SettingsViewModel
    @FocusState private var isPINFocused: Bool
    /// 連携を解除するか確かめている設定
    @State private var unlinking: ServerSetupServer?

    init(settings: SettingsViewModel) {
        _settings = State(initialValue: settings)
    }

    /// 設定の画面。テレビの設定と、録画サーバー (Mirakurun・EPGStation) の設定を別の画面に分ける
    private typealias Page = SettingsPage

    /// 開いている設定の画面 (テレビが未設定なら、SettingsViewModel がテレビの設定の画面から開く)
    private var path: Binding<[Page]> {
        Binding(get: { settings.state.path }, set: { settings.send(.setPath($0)) })
    }

    var body: some View {
        let state = settings.state
        let tvState = state.tv
        let serverState = state.servers
        NavigationStack(path: path) {
            Form {
                Section("テレビ") {
                    NavigationLink(value: Page.tv) {
                        LabeledContent("REGZA") {
                            Text(tvState.status.text)
                                .foregroundStyle(tvState.status.needsAttention ? Color.orange : .secondary)
                        }
                    }
                }

                Section("表示") {
                    LiveActivityToggle()
                }

                Section {
                    NavigationLink(value: Page.guide) {
                        LabeledContent("番組表（Mirakurun）", value: serverState.guide.status)
                    }
                    // EPGStation は Mirakurun から放送を受け取るので、Mirakurun を設定してから設定できるようにする
                    NavigationLink(value: Page.stream) {
                        LabeledContent(
                            "ライブ視聴（EPGStation）",
                            value: serverState.hasGuideDraft ? serverState.stream.status : "先に番組表を設定")
                    }
                    .disabled(!serverState.hasGuideDraft)
                } header: {
                    Text("録画サーバーとの連携")
                } footer: {
                    Text(
                        """
                        Mirakurun や EPGStation を使っている場合だけ設定してください。設定すると、番組名・番組表・番組表からの録画予約や、アプリでのライブ視聴が使えます。
                        ライブ視聴（EPGStation）は、番組表（Mirakurun）を設定すると設定できます。
                        """)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .tv:
                    tvPage
                case .guide:
                    serverPage(.guide, title: "番組表（Mirakurun）")
                case .stream:
                    serverPage(.stream, title: "ライブ視聴（EPGStation）")
                }
            }
            // iOS 26 の標準に合わせ、キャンセルは ×、保存は ✓ (強調色) のボタンにする
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { settings.send(.close) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // 保存できたら SettingsViewModel が設定を閉じる
                    Button(role: .confirm) { settings.send(.save) }
                        .disabled(!state.canSave)
                }
            }
            // テレビに PIN が出たら、すぐ打てるようにする
            .onChange(of: tvState.isWaitingForPIN) { _, isWaiting in
                if isWaiting { isPINFocused = true }
            }
        }
    }

    /// 入力欄を ViewModel につなぐ (打つたびに操作として送る)
    private func binding<Value>(_ value: Value, _ action: @escaping (Value) -> TVSetupAction) -> Binding<Value> {
        Binding(get: { value }, set: { settings.send(.tv(action($0))) })
    }

    /// テレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
    private var tvPage: some View {
        let state = settings.state.tv
        return Form {
            Section {
                TextField("IPアドレス (例: 192.168.0.10)", text: binding(state.host) { .setHost($0) })
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(state.isWaitingForPIN)
                ForEach(state.devices) { row in
                    Button {
                        settings.send(.tv(.select(row.host)))
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
                    settings.send(.tv(.scan))
                } label: {
                    HStack {
                        Label(state.isScanning ? "テレビを探しています…" : "テレビを探す", systemImage: "magnifyingglass")
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
                Text("テレビ")
            } footer: {
                Text("iPhone とテレビを同じ Wi-Fi につないでください。見つからないときは、テレビの「設定」→「ネットワーク」で IP アドレスを確認して入力してください。")
            }

            pairingSection(state)

            Section {
                DisclosureGroup("ユーザー名とパスワードを入力", isExpanded: binding(state.isShowingManualEntry) { .setShowingManualEntry($0) }) {
                    TextField("ユーザー名", text: binding(state.user) { .setUser($0) })
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("パスワード", text: binding(state.password) { .setPassword($0) })
                }
            } footer: {
                Text("PIN 登録に対応していない古い機種では、テレビの「外部連携設定」で設定したユーザー名とパスワードを入力してください。")
            }

            Section {
                Button {
                    settings.send(.tv(.test))
                } label: {
                    HStack {
                        Text("接続テスト")
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
        .onAppear { settings.send(.tv(.appear)) }
    }

    private func pairingSection(_ state: TVSetupState) -> some View {
        Section {
            if !state.isWaitingForPIN {
                Button {
                    settings.send(.tv(.startPairing))
                } label: {
                    HStack {
                        Label(state.isRegistered ? "もう一度登録する" : "テレビに PIN を表示", systemImage: "number.square")
                        Spacer()
                        if state.isPairing { ProgressView() }
                    }
                }
                .disabled(!state.hasAddress || state.isPairing)
            } else {
                TextField("テレビに表示された PIN", text: binding(state.pin) { .setPIN($0) })
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title3.monospacedDigit())
                    .focused($isPINFocused)
                Button {
                    settings.send(.tv(.confirmPairing))
                } label: {
                    HStack {
                        Text("登録")
                        Spacer()
                        if state.isPairing { ProgressView() }
                    }
                }
                .disabled(state.pin.isEmpty || state.isPairing)
                Button("やめる", role: .cancel) {
                    settings.send(.tv(.cancelPairing))
                }
                .disabled(state.isPairing)
            }
            if let pairingMessage = state.pairingMessage {
                Text(pairingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("PIN で登録")
        } footer: {
            if !state.isWaitingForPIN {
                Text("テレビの電源を入れてからボタンを押すと、テレビの画面に PIN が表示されます。")
            } else {
                Text("テレビの画面に表示されている PIN を入力してください。")
            }
        }
    }

    /// 録画サーバーの設定の画面。保存済みなら、連携を解除するボタンも出す
    private func serverPage(_ server: ServerSetupServer, title: String) -> some View {
        let state = settings.state.servers[server]
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
                host: Binding(get: { state.host }, set: { settings.send(.server(.setHost(server, $0))) }),
                defaultPort: state.defaultPort
            )
            ForEach(state.hosts, id: \.self) { host in
                Button {
                    settings.send(.server(.setHost(server, host)))
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
                settings.send(.server(.scan(server)))
            } label: {
                HStack {
                    Label(state.isScanning ? "\(name) を探しています…" : "\(name) を探す", systemImage: "magnifyingglass")
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
            Text(server == .guide ? "番組表 (Mirakurun)" : "ライブ視聴 (EPGStation)")
        } footer: {
            Text(
                server == .guide
                    ? "Mirakurun を動かしている場合に設定すると、放送中の番組名と番組表を表示します。使わない場合は空のままにしてください。"
                    : "EPGStation を動かしている場合に設定すると、放送中の番組を iPhone で見られます。家の Wi-Fi の中だけで使えます。")
        }
    }

    /// 録画サーバーとの連携をやめる。確かめたうえで、すぐにアドレスを消して反映する
    private func unlinkSection(_ server: ServerSetupServer, _ state: ServerSetupServerState) -> some View {
        Section {
            Button("連携を解除", role: .destructive) { unlinking = server }
                .confirmationDialog(
                    state.unlinkTitle,
                    isPresented: Binding(get: { unlinking == server }, set: { if !$0 { unlinking = nil } }),
                    titleVisibility: .visible
                ) {
                    // SettingsViewModel が、その設定の画面を閉じる
                    Button("連携を解除", role: .destructive) { settings.send(.server(.unlink(server))) }
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
            TextField("IPアドレス (例: 192.168.0.2)", text: address)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Divider()
            // 標準のポートを薄く出し、空なら標準のポートを使う
            TextField(String(defaultPort), text: port)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .accessibilityLabel("ポート")
        }
        if !ServerAddress(host).isValid {
            Text("ポートは 1〜65535 の数字で入れてください。空のままなら \(defaultPort) を使います。")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }
}
#endif
