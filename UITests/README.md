# Maestro による UI テスト

設定入力とキャンセル、番組表→検索→詳細→戻る、バックグラウンド・終了後の入力復元を両 OS で確認する。SwiftUI / Compose の実際の画面を操作し、通常の URLSession / OkHttp、生成 APIClient、Repository、ViewModel を通す。

```sh
mise -C UITests install
# 起動済みの専用端末を指定する。アプリのデータを初期化するため、普段使う端末とは分ける。
ANDROID_SERIAL=emulator-5554 mise run test-ui-android
IOS_SIMULATOR_UDID=<UDID> mise run test-ui-ios
```

タスクは debug アプリのビルド・インストール、HTTP スタブの起動、Maestro、後片づけまで行う。iOS は macOS / Xcode のシミュレーターを使用する。Android は既存の開発環境に加えて `adb reverse` を使用する。Maestro・Java はこのディレクトリのmise設定、共通のBunはルートのmise設定で固定する。Maestroは通常のビルドやCIの導入対象に含めない。

iOS のバンドル ID はビルドした Info.plist から取得するため、Local.xcconfig の変更も反映される。結果・スクリーンショット・ログは `.build/<OS>-results/`、HTTP リクエストの記録は `.build/server-<OS>.log` に置く。

## 起動設定と通信

`run.sh` がローカルの `server.ts` を空いているポートで起動する。Maestro の起動引数 `UITestServer` には接続先だけを渡す。iOS は `ProcessInfo.arguments`、Android は Intent extras で読み、UserDefaults / SharedPreferences へフラグや接続先を保存しない。iOS は `UITEST_SERVER` 環境変数でも同じ設定を受け取れる（XCUITest の launchEnvironment など）。Maestro のフローでは公開されている起動引数 API を使用する。

起動口は debug ビルドだけで有効。接続設定はプロセス内のメモリに置き、通信処理や応答データの差し替えはアプリ内で行わない。SampleData / SampleTransport は使用しない。復元機能は本番と同じように有効にする。HTTP スタブが返す架空のテレビと番組だけを使い、実際のテレビ・録画サーバーには接続しない。

## フロー

- `01-settings.yaml`: 接続先を編集し、保存せず閉じて開き直すと元の設定が表示される。
- `02-navigation.yaml`: 番組表から検索し、番組詳細を開いて検索結果へ戻る。
- `03-restoration.yaml`: 編集した接続先を、ホームからの復帰とアプリ終了後に復元する。終了前にバックグラウンドへ移し、復帰には `stopApp: false` を指定する。Android の `killApp` はバックグラウンドのプロセスを終了する。

固定時間の待機や座標操作は使わず、表示条件と要素の ID を使用する。ネイティブの戻る操作など OS 間で異なる部分だけフローで分岐する。テスト用 ID は画面の表示・読み上げテキストを変更しない。

既存の Swift・JNI・通信・ライフサイクルテストは継続する。端末が必要なため、Maestro は `mise run check` や既存の CI には含めず、まずローカルで明示的に実行する。
