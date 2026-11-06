#if os(iOS)
import RegzaCore
import SwiftUI

struct SettingsView: View {
    @State private var tv: TVSetupViewModel
    @State private var servers: ServerSetupViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPINFocused: Bool
    /// 連携を解除するか確かめている設定
    @State private var unlinking: ServerSetupViewModel.Server?

    init(tv: TVSetupViewModel, servers: ServerSetupViewModel) {
        _tv = State(initialValue: tv)
        _servers = State(initialValue: servers)
    }

    /// 設定の画面。テレビの設定と、録画サーバー (Mirakurun・EPGStation) の設定を別の画面に分ける
    private enum Page: Hashable {
        case tv, guide, stream
    }

    /// 最初はテレビが未設定なら、テレビの設定の画面を開いておく
    @State private var path: [Page] = []
    /// 最初に開いたときだけ、テレビの設定の画面を開く
    @State private var hasOpened = false

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section("テレビ") {
                    NavigationLink(value: Page.tv) {
                        LabeledContent("REGZA") {
                            Text(tv.status.text)
                                .foregroundStyle(tv.status.needsAttention ? Color.orange : .secondary)
                        }
                    }
                }

                Section("表示") {
                    LiveActivityToggle()
                }

                Section {
                    NavigationLink(value: Page.guide) {
                        LabeledContent("番組表（Mirakurun）", value: servers.status(of: .guide))
                    }
                    // EPGStation は Mirakurun から放送を受け取るので、Mirakurun を設定してから設定できるようにする
                    NavigationLink(value: Page.stream) {
                        LabeledContent("ライブ視聴（EPGStation）",
                                       value: servers.hasGuideDraft ? servers.status(of: .stream) : "先に番組表を設定")
                    }
                    .disabled(!servers.hasGuideDraft)
                } header: {
                    Text("録画サーバーとの連携")
                } footer: {
                    Text("""
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
                    Form {
                        guideSection
                        if servers.isLinked(.guide) { unlinkSection(.guide) }
                    }
                    .navigationTitle("番組表（Mirakurun）")
                    .navigationBarTitleDisplayMode(.inline)
                case .stream:
                    Form {
                        streamSection
                        if servers.isLinked(.stream) { unlinkSection(.stream) }
                    }
                    .navigationTitle("ライブ視聴（EPGStation）")
                    .navigationBarTitleDisplayMode(.inline)
                    .task { await servers.suggestStreamHost() }
                }
            }
            // iOS 26 の標準に合わせ、キャンセルは ×、保存は ✓ (強調色) のボタンにする
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        Task {
                            await servers.save()
                            await tv.save()
                            dismiss()
                        }
                    }
                    .disabled(!tv.canSave || !servers.isValid)
                }
            }
            .onAppear {
                // 各設定の画面から一覧に戻ったときにも呼ばれるので、最初の 1 回だけにする
                guard !hasOpened else { return }
                hasOpened = true
                if !tv.remote.connection.isConfigured, path.isEmpty { path = [.tv] }
            }
            .onDisappear { tv.close() }
            // テレビに PIN が出たら、すぐ打てるようにする
            .onChange(of: tv.isWaitingForPIN) { _, isWaiting in
                if isWaiting { isPINFocused = true }
            }
        }
    }

    /// テレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
    private var tvPage: some View {
        Form {
            Section {
                TextField("IPアドレス (例: 192.168.0.10)", text: $tv.draft.host)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(tv.isWaitingForPIN)
                ForEach(tv.devices) { device in
                    Button {
                        Task { await tv.select(device) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                Text(device.host)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if tv.isSelected(device) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .tint(.primary)
                    .disabled(tv.isWaitingForPIN)
                }
                Button {
                    Task { await tv.scan() }
                } label: {
                    HStack {
                        Label(tv.isScanning ? "テレビを探しています…" : "テレビを探す", systemImage: "magnifyingglass")
                        Spacer()
                        if tv.isScanning { ProgressView() }
                    }
                }
                .disabled(tv.isScanning || tv.isWaitingForPIN)
                if let scanMessage = tv.scanMessage {
                    Text(scanMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("テレビ")
            } footer: {
                Text("iPhone とテレビを同じ Wi-Fi につないでください。見つからないときは、テレビの「設定」→「ネットワーク」で IP アドレスを確認して入力してください。")
            }


            pairingSection

            Section {
                DisclosureGroup("ユーザー名とパスワードを入力", isExpanded: $tv.isShowingManualEntry) {
                    TextField("ユーザー名", text: $tv.draft.user)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("パスワード", text: $tv.draft.password)
                }
            } footer: {
                Text("PIN 登録に対応していない古い機種では、テレビの「外部連携設定」で設定したユーザー名とパスワードを入力してください。")
            }

            Section {
                Button {
                    Task { await tv.test() }
                } label: {
                    HStack {
                        Text("接続テスト")
                        Spacer()
                        if tv.isTesting { ProgressView() }
                    }
                }
                .disabled(!tv.draft.isConfigured || tv.isTesting)
                if let testResult = tv.testResult {
                    Text(testResult)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("REGZA")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // 未設定なら開いたときに探し始める
            if tv.shouldScanOnOpen { await tv.scan() }
        }
    }

    /// 録画サーバーとの連携をやめる。確かめたうえで、すぐにアドレスを消して反映する
    private func unlinkSection(_ server: ServerSetupViewModel.Server) -> some View {
        let question = servers.unlinkQuestion(server)
        return Section {
            Button("連携を解除", role: .destructive) { unlinking = server }
                .confirmationDialog(
                    question.title,
                    isPresented: Binding(get: { unlinking == server }, set: { if !$0 { unlinking = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("連携を解除", role: .destructive) {
                        Task {
                            await servers.unlink(server)
                            path.removeAll { $0 == (server == .guide ? .guide : .stream) }
                        }
                    }
                } message: {
                    Text(question.message)
                }
        }
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            if !tv.isWaitingForPIN {
                Button {
                    Task { await tv.startPairing() }
                } label: {
                    HStack {
                        Label(tv.isRegistered ? "もう一度登録する" : "テレビに PIN を表示", systemImage: "number.square")
                        Spacer()
                        if tv.isPairing { ProgressView() }
                    }
                }
                .disabled(!tv.draft.isConfigured || tv.isPairing)
            } else {
                TextField("テレビに表示された PIN", text: $tv.pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title3.monospacedDigit())
                    .focused($isPINFocused)
                Button {
                    Task {
                        if await tv.confirmPairing() { dismiss() }
                    }
                } label: {
                    HStack {
                        Text("登録")
                        Spacer()
                        if tv.isPairing { ProgressView() }
                    }
                }
                .disabled(tv.pin.isEmpty || tv.isPairing)
                Button("やめる", role: .cancel) {
                    Task { await tv.cancelPairing() }
                }
                .disabled(tv.isPairing)
            }
            if let pairingMessage = tv.pairingMessage {
                Text(pairingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("PIN で登録")
        } footer: {
            if !tv.isWaitingForPIN {
                Text("テレビの電源を入れてからボタンを押すと、テレビの画面に PIN が表示されます。")
            } else {
                Text("テレビの画面に表示されている PIN を入力してください。")
            }
        }
    }

    @ViewBuilder
    private var guideSection: some View {
        Section {
            ServerAddressField(host: $servers.guideHost, defaultPort: Mirakurun.defaultPort)
            ForEach(servers.guideHosts, id: \.self) { host in
                Button {
                    servers.guideHost = host
                } label: {
                    HStack {
                        Text(host).monospacedDigit()
                        Spacer()
                        if servers.guideHost == host {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
            Button {
                Task { await servers.scanGuide() }
            } label: {
                HStack {
                    Label(servers.isScanningGuide ? "Mirakurun を探しています…" : "Mirakurun を探す", systemImage: "magnifyingglass")
                    Spacer()
                    if servers.isScanningGuide { ProgressView() }
                }
            }
            .disabled(servers.isScanningGuide)
            if let guideMessage = servers.guideMessage {
                Text(guideMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("番組表 (Mirakurun)")
        } footer: {
            Text("Mirakurun を動かしている場合に設定すると、放送中の番組名と番組表を表示します。使わない場合は空のままにしてください。")
        }
    }

    @ViewBuilder
    private var streamSection: some View {
        Section {
            ServerAddressField(host: $servers.streamHost, defaultPort: EPGStation.defaultPort)
            ForEach(servers.streamHosts, id: \.self) { host in
                Button {
                    servers.streamHost = host
                } label: {
                    HStack {
                        Text(host).monospacedDigit()
                        Spacer()
                        if servers.streamHost == host {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
            Button {
                Task { await servers.scanStream() }
            } label: {
                HStack {
                    Label(servers.isScanningStream ? "EPGStation を探しています…" : "EPGStation を探す", systemImage: "magnifyingglass")
                    Spacer()
                    if servers.isScanningStream { ProgressView() }
                }
            }
            .disabled(servers.isScanningStream)
            if let streamMessage = servers.streamMessage {
                Text(streamMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("ライブ視聴 (EPGStation)")
        } footer: {
            Text("EPGStation を動かしている場合に設定すると、放送中の番組を iPhone で見られます。家の Wi-Fi の中だけで使えます。")
        }
    }
}

/// アドレスとポートを別々に入れる欄。ポートが空なら標準のポートを使う
private struct ServerAddressField: View {
    @Binding var host: String
    let defaultPort: Int

    private var address: Binding<String> {
        Binding(get: { ServerAddress(host).address },
                set: { host = ServerAddress(address: $0, port: ServerAddress(host).port).combined })
    }

    private var port: Binding<String> {
        Binding(get: { ServerAddress(host).port },
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
