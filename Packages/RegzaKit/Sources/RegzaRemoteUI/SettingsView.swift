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


    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("IPアドレス (例: 192.168.0.10)", text: $draft.host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(pairing != nil)
                } header: {
                    Text("テレビ")
                } footer: {
                    Text("テレビの「設定」→「ネットワーク」で IP アドレスを確認できます。iPhone とテレビを同じ Wi-Fi につないでください。")
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
            .onAppear { draft = model.connection }
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

    private var isRegistered: Bool {
        RegzaPairing.isUserID(draft.user) && !draft.password.isEmpty
    }

    private func startPairing() async {
        isPairing = true
        defer { isPairing = false }
        pairingMessage = nil
        // 登録し直すときは同じ ID を使い、テレビの登録機器が増えないようにする
        let session = RegzaPairing(
            host: draft.host,
            user: RegzaPairing.isUserID(draft.user) ? draft.user : RegzaPairing.makeUserID()
        )
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
        case .success(let status):
            testResult = status.isPlayingRecording
                ? "接続できました: \(status.titleName)"
                : "接続できました"
        case .failure(let error):
            testResult = error.localizedDescription
        }
    }
}
#endif
