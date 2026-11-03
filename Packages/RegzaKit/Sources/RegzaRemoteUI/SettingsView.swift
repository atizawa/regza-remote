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

    var body: some View {
        NavigationStack {
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
            .navigationTitle("接続設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await model.save(draft)
                            dismiss()
                        }
                    }
                    .disabled(!draft.isConfigured || pairing != nil)
                }
            }
            .onAppear {
                draft = model.connection
                pairingUserID = model.pairingUserID()
            }
            .task {
                // 未設定なら開いたときに探し始める
                if !model.connection.isConfigured { await scan() }
            }
            .onDisappear {
                // PIN を入れずに閉じたら、テレビの PIN 表示を消しておく
                if let pairing { Task { await pairing.cancel() } }
            }
        }
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
