# REGZA リモコン

REGZA の HTTP リモコン API（[参考](https://misomayo.info/on/2012/04/10)）を使う iOS アプリ。
録画番組の再生中は、番組名・再生位置を Dynamic Island / ロック画面の Live Activity に表示し、そこから音量・チャンネル・再生操作もできる。

## 構成

```
Packages/RegzaKit/            Swift Package（マルチモジュール）
  RegzaCore                   クロスプラットフォーム（Foundation のみ）。Android でも使う想定
                              キーコード / Digest 認証 / HTTP クライアント / status.htm 解析 / RegzaRemote
  RegzaAppleStorage           キーチェーンへの接続情報保存
  RegzaLiveActivity           Live Activity・Dynamic Island の UI と、ボタン用 App Intent（iOS）
  RegzaRemoteUI               SwiftUI のリモコン画面（iOS）
iOS/RegzaRemote.xcodeproj     アプリ・ウィジェット拡張（モジュールを組み立てるだけの薄い層）
```

- Digest 認証は URLSession の認証チャレンジに頼らず `RegzaCore` で自前実装している（Android の FoundationNetworking でも同じコードで動かすため）
- iOS 専用モジュールは `#if os(iOS)` で囲んであるので、パッケージ全体を他プラットフォーム向けにビルドしても壊れない

## 開発

```sh
cd Packages/RegzaKit && swift test        # コアのテスト
open iOS/RegzaRemote.xcodeproj            # Signing の Team と Bundle ID を設定して実機へ
```

## テレビ側の準備

- アプリの設定画面で IP アドレスを入力し、「テレビに PIN を表示」→ テレビに出た PIN を入力して登録する（レグザAppsコネクト v2 の `request_connection` / `confirm_connection`）
  - パスワードは PIN から作った鍵（PBKDF2-HMAC-SHA1, 1331 回）の AES-128-CBC で暗号化されて届く。Android でも動くよう SHA-1 / AES は `RegzaCore` で自前実装している
- PIN 登録に対応していない機種は、テレビの外部連携設定で決めたユーザー名・パスワードを手入力する
- 電源 ON をスマホから行うには、待機時の通信（クイック起動など）を有効にする

## 視聴状況の取得

- レグザAppsコネクト v2 API の `GET /v2/remote/play/status` を優先して使う（HTTP 80番で動作）
  - 放送: チャンネル名、番組の開始時刻・長さ、次の番組の開始時刻
  - 録画再生: 番組名、番組説明、再生位置、再生/一時停止
  - 外部入力 (HDMI)・待機中も判別できる
- v2 API が無い機種（404 など）では旧 API の `status.htm` に切り替える（録画再生中の情報のみ）
- 対応 API の一覧は `GET /v2/remote/support` で確認できる

## 制限

- 機種によっては v2 API が放送中の番組名・番組説明を空文字で返すため、放送中はチャンネル名と放送時間のみ表示する（`/v2/remote/epg/:channel_code` も同様）
- Live Activity はアプリがフォアグラウンドの間だけ自動更新される。バックグラウンドでは、Live Activity のボタンを押したときに更新される

## Android 展開（予定）

`RegzaCore` を Swift SDK for Android でビルドし、JNI 経由で Kotlin / Jetpack Compose の UI から呼ぶ。
接続情報の保存は `RegzaConnectionStore` を Android 側で実装する。
