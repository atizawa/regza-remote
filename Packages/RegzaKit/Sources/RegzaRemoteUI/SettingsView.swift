#if os(iOS)
import RegzaCore
import SwiftUI

struct SettingsView: View {
    @Environment(RemoteViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RegzaConnection()
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("IPアドレス (例: 192.168.0.10)", text: $draft.host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("ユーザー名", text: $draft.user)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("パスワード", text: $draft.password)
                } header: {
                    Text("テレビ")
                } footer: {
                    Text("テレビの「外部連携設定」→「レグザApps」などでユーザー名とパスワードを設定してください。スマホから電源を入れるには、テレビ側で待機時の通信を有効にしておく必要があります。")
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
                    .disabled(!draft.isConfigured)
                }
            }
            .onAppear { draft = model.connection }
        }
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
