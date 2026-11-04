#if os(iOS)
import RegzaCore
import SwiftUI

struct SettingsView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RegzaConnection()
    @State private var testResult: String?
    @State private var isTesting = false

    /// PIN 登録中 (テレビに PIN が表示されている間) のセッション
    @State private var pairing: RegzaPairing?
    @State private var pin = ""
    @State private var isPairing = false
    @State private var pairingMessage: String?
    @State private var isShowingManualEntry = false
    @FocusState private var isPINFocused: Bool
    /// このアプリ用のユーザー ID。手入力のユーザー名は他のツールと共有している
    /// かもしれないので使い回さない (同じ ID で登録し直すと、前のパスワードが無効になる)
    @State private var pairingUserID = ""

    /// 自動検出で見つかったテレビ
    @State private var devices: [RegzaDevice] = []
    @State private var isScanning = false
    @State private var scanMessage: String?

    /// 番組表 (Mirakurun) のアドレス
    @State private var guideHost = ""
    @State private var guideHosts: [String] = []
    @State private var isScanningGuide = false
    @State private var guideMessage: String?

    /// ライブ視聴 (EPGStation) のアドレス
    @State private var streamHost = ""
    @State private var streamHosts: [String] = []
    @State private var isScanningStream = false
    @State private var streamMessage: String?
    /// 連携を解除するか確かめている設定
    @State private var unlinking: Page?

    /// 設定の画面。テレビの設定と、録画サーバー (Mirakurun・EPGStation) の設定を別の画面に分ける
    private enum Page: Hashable {
        case tv, guide, stream
    }

    /// 最初はテレビが未設定なら、テレビの設定の画面を開いておく
    @State private var path: [Page] = []
    /// 保存済みの値を読み込んだか
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section("テレビ") {
                    NavigationLink(value: Page.tv) {
                        LabeledContent("REGZA", value: tvStatus)
                    }
                }

                Section("表示") {
                    LiveActivityToggle()
                }

                Section {
                    NavigationLink(value: Page.guide) {
                        LabeledContent("番組表（Mirakurun）", value: status(of: guideHost))
                    }
                    // EPGStation は Mirakurun から放送を受け取るので、Mirakurun を設定してから設定できるようにする
                    NavigationLink(value: Page.stream) {
                        LabeledContent("ライブ視聴（EPGStation）",
                                       value: hasGuideDraft ? status(of: streamHost) : "先に番組表を設定")
                    }
                    .disabled(!hasGuideDraft)
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
                        if !model.guideHost.isEmpty { unlinkSection(.guide) }
                    }
                    .navigationTitle("番組表（Mirakurun）")
                    .navigationBarTitleDisplayMode(.inline)
                case .stream:
                    Form {
                        streamSection
                        if !model.streamHost.isEmpty { unlinkSection(.stream) }
                    }
                    .navigationTitle("ライブ視聴（EPGStation）")
                    .navigationBarTitleDisplayMode(.inline)
                    .task { await suggestStreamHost() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await model.saveGuideHost(guideHost)
                            model.saveStreamHost(streamHost)
                            await model.save(draft)
                            dismiss()
                        }
                    }
                    .disabled(!draft.isConfigured || pairing != nil)
                }
            }
            .onAppear {
                // 各設定の画面から一覧に戻ったときにも呼ばれるので、読み込むのは最初の 1 回だけにする
                // (毎回読み込むと、入力したアドレスが保存済みの値に戻ってしまう)
                guard !hasLoaded else { return }
                hasLoaded = true
                draft = model.connection
                pairingUserID = model.pairingUserID()
                guideHost = model.guideHost
                streamHost = model.streamHost
                if !model.connection.isConfigured, path.isEmpty { path = [.tv] }
            }
            .onDisappear {
                // PIN を入れずに閉じたら、テレビの PIN 表示を消しておく
                if let pairing { Task { await pairing.cancel() } }
            }
        }
    }

    /// テレビを探す・PIN で登録する・ユーザー名とパスワード・接続テスト
    private var tvPage: some View {
        Form {
            Section {
                TextField("IPアドレス (例: 192.168.0.10)", text: $draft.host)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(pairing != nil)
                ForEach(devices) { device in
                    Button {
                        Task { await select(device) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                Text(device.host)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if draft.host == device.host {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .tint(.primary)
                    .disabled(pairing != nil)
                }
                Button {
                    Task { await scan() }
                } label: {
                    HStack {
                        Label(isScanning ? "テレビを探しています…" : "テレビを探す", systemImage: "magnifyingglass")
                        Spacer()
                        if isScanning { ProgressView() }
                    }
                }
                .disabled(isScanning || pairing != nil)
                if let scanMessage {
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
                DisclosureGroup("ユーザー名とパスワードを入力", isExpanded: $isShowingManualEntry) {
                    TextField("ユーザー名", text: $draft.user)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("パスワード", text: $draft.password)
                }
            } footer: {
                Text("PIN 登録に対応していない古い機種では、テレビの「外部連携設定」で設定したユーザー名とパスワードを入力してください。")
            }

            Section {
                Button {
                    Task { await test() }
                } label: {
                    HStack {
                        Text("接続テスト")
                        Spacer()
                        if isTesting { ProgressView() }
                    }
                }
                .disabled(!draft.isConfigured || isTesting)
                if let testResult {
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
            if !model.connection.isConfigured, devices.isEmpty { await scan() }
        }
    }

    /// 録画サーバーとの連携をやめる。確かめたうえで、すぐにアドレスを消して反映する
    private func unlinkSection(_ page: Page) -> some View {
        Section {
            Button("連携を解除", role: .destructive) { unlinking = page }
                .confirmationDialog(
                    page == .guide ? "Mirakurun との連携を解除しますか？" : "EPGStation との連携を解除しますか？",
                    isPresented: Binding(get: { unlinking == page }, set: { if !$0 { unlinking = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("連携を解除", role: .destructive) {
                        Task { await unlink(page) }
                    }
                } message: {
                    Text(page == .guide
                         ? "番組名・番組表・番組表からの録画予約が使えなくなります。ライブ視聴（EPGStation）の連携も解除されます。"
                         : "アプリでのライブ視聴が使えなくなります。")
                }
        }
    }

    private func unlink(_ page: Page) async {
        switch page {
        case .guide:
            guideHost = ""
            guideHosts = []
            await model.saveGuideHost("")
            // EPGStation だけでは使えないので、一緒に解除する
            streamHost = ""
            streamHosts = []
            model.saveStreamHost("")
        case .stream:
            streamHost = ""
            streamHosts = []
            model.saveStreamHost("")
        case .tv:
            return
        }
        path.removeAll { $0 == page }
    }

    /// Mirakurun のアドレスが入っているか (保存前の入力も含む)
    private var hasGuideDraft: Bool {
        !guideHost.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Mirakurun と同じサーバーで EPGStation が動いていれば、候補として出す
    private func suggestStreamHost() async {
        guard streamHost.trimmingCharacters(in: .whitespaces).isEmpty, streamHosts.isEmpty else { return }
        // Mirakurun のアドレスからポートを除いたもの
        let server = guideHost.trimmingCharacters(in: .whitespaces).split(separator: ":").first.map(String.init) ?? ""
        guard !server.isEmpty, await EPGStation(host: server, timeout: 3).isAvailable() else { return }
        streamHosts = [server]
        streamHost = server
        streamMessage = "Mirakurun と同じサーバーで EPGStation が見つかりました。よければ「保存」を押してください。"
    }

    private var tvStatus: String {
        let host = draft.host.trimmingCharacters(in: .whitespaces)
        if host.isEmpty { return "未設定" }
        return isRegistered ? "\(host)・登録済み" : host
    }

    private func status(of host: String) -> String {
        let host = host.trimmingCharacters(in: .whitespaces)
        return host.isEmpty ? "未設定" : host
    }

    @ViewBuilder
    private var pairingSection: some View {
        Section {
            if pairing == nil {
                Button {
                    Task { await startPairing() }
                } label: {
                    HStack {
                        Label(isRegistered ? "もう一度登録する" : "テレビに PIN を表示", systemImage: "number.square")
                        Spacer()
                        if isPairing { ProgressView() }
                    }
                }
                .disabled(!draft.isConfigured || isPairing)
            } else {
                TextField("テレビに表示された PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.title3.monospacedDigit())
                    .focused($isPINFocused)
                Button {
                    Task { await confirmPairing() }
                } label: {
                    HStack {
                        Text("登録")
                        Spacer()
                        if isPairing { ProgressView() }
                    }
                }
                .disabled(pin.isEmpty || isPairing)
                Button("やめる", role: .cancel) {
                    Task { await cancelPairing() }
                }
                .disabled(isPairing)
            }
            if let pairingMessage {
                Text(pairingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("PIN で登録")
        } footer: {
            if pairing == nil {
                Text("テレビの電源を入れてからボタンを押すと、テレビの画面に PIN が表示されます。")
            } else {
                Text("テレビの画面に表示されている PIN を入力してください。")
            }
        }
    }

    @ViewBuilder
    private var guideSection: some View {
        Section {
            TextField("IPアドレス (例: 192.168.0.2)", text: $guideHost)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            ForEach(guideHosts, id: \.self) { host in
                Button {
                    guideHost = host
                } label: {
                    HStack {
                        Text(host).monospacedDigit()
                        Spacer()
                        if guideHost == host {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
            Button {
                Task { await scanGuide() }
            } label: {
                HStack {
                    Label(isScanningGuide ? "Mirakurun を探しています…" : "Mirakurun を探す", systemImage: "magnifyingglass")
                    Spacer()
                    if isScanningGuide { ProgressView() }
                }
            }
            .disabled(isScanningGuide)
            if let guideMessage {
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
            TextField("IPアドレス (例: 192.168.0.2)", text: $streamHost)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            ForEach(streamHosts, id: \.self) { host in
                Button {
                    streamHost = host
                } label: {
                    HStack {
                        Text(host).monospacedDigit()
                        Spacer()
                        if streamHost == host {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
            Button {
                Task { await scanStream() }
            } label: {
                HStack {
                    Label(isScanningStream ? "EPGStation を探しています…" : "EPGStation を探す", systemImage: "magnifyingglass")
                    Spacer()
                    if isScanningStream { ProgressView() }
                }
            }
            .disabled(isScanningStream)
            if let streamMessage {
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

    private func scanStream() async {
        isScanningStream = true
        defer { isScanningStream = false }
        streamMessage = nil
        streamHosts = await EPGStation.find()
        if let first = streamHosts.first, streamHost.trimmingCharacters(in: .whitespaces).isEmpty {
            streamHost = first
        }
        if streamHosts.isEmpty {
            streamMessage = "見つかりませんでした。EPGStation が動いているか、ポート \(EPGStation.defaultPort) で待ち受けているか確認してください。"
        }
    }

    private func scanGuide() async {
        isScanningGuide = true
        defer { isScanningGuide = false }
        guideMessage = nil
        guideHosts = await Mirakurun.find()
        if let first = guideHosts.first, guideHost.trimmingCharacters(in: .whitespaces).isEmpty {
            guideHost = first
        }
        if guideHosts.isEmpty {
            guideMessage = "見つかりませんでした。Mirakurun が動いているか、ポート \(Mirakurun.defaultPort) で待ち受けているか確認してください。"
        }
    }

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        scanMessage = nil
        devices = []
        for await device in RegzaDiscovery.devices() {
            devices.append(device)
            // 1 台目は選んでおく。登録は利用者がボタンを押してから
            if devices.count == 1, draft.host.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.host = device.host
            }
        }
        if devices.isEmpty {
            scanMessage = "見つかりませんでした。テレビの電源が入っているか、iPhone の「設定」→「プライバシーとセキュリティ」→「ローカルネットワーク」でこのアプリが許可されているか確認してください。"
        }
    }

    /// 未登録なら、選んだテレビにそのまま PIN を表示させる。
    /// 登録済みなら IP アドレスだけ変える (DHCP でアドレスが変わった場合など)
    private func select(_ device: RegzaDevice) async {
        draft.host = device.host
        if device.supportsPIN, !isRegistered { await startPairing() }
    }

    private var isRegistered: Bool {
        !pairingUserID.isEmpty && draft.user == pairingUserID && !draft.password.isEmpty
    }

    private func startPairing() async {
        isPairing = true
        defer { isPairing = false }
        pairingMessage = nil
        // 登録し直すときはアプリの ID を使い回し、テレビの登録機器が増えないようにする
        let session = RegzaPairing(host: draft.host, user: pairingUserID)
        do {
            try await session.start()
            pairing = session
            pin = ""
            isPINFocused = true
        } catch RegzaError.unsupported, RegzaError.httpStatus(404) {
            pairingMessage = "この機種は PIN 登録に対応していません。下の「ユーザー名とパスワードを入力」から設定してください。"
            isShowingManualEntry = true
        } catch {
            pairingMessage = error.localizedDescription
        }
    }

    private func confirmPairing() async {
        guard let pairing else { return }
        isPairing = true
        defer { isPairing = false }
        do {
            draft = try await pairing.confirm(pin: pin)
            self.pairing = nil
            await model.save(draft)
            dismiss()
        } catch {
            // PIN の打ち間違いはそのまま入力し直せるようにする
            pairingMessage = error.localizedDescription
        }
    }

    private func cancelPairing() async {
        await pairing?.cancel()
        pairing = nil
        pin = ""
        pairingMessage = nil
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        switch await model.testConnection(draft) {
        case .success(let nowPlaying):
            let detail = nowPlaying.title.isEmpty ? nowPlaying.channelName : nowPlaying.title
            testResult = detail.isEmpty ? "接続できました" : "接続できました: \(detail)"
        case .failure(let error):
            testResult = error.localizedDescription
        }
    }
}
#endif
