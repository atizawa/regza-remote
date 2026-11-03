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

- 設定画面の「テレビを探す」で同じネットワークの REGZA を検出する
  - 自分の /24 のアドレスすべてに `GET /public/feature`（認証不要）を並列に問い合わせ、`device_type` が `DTV` のものを候補にする。応答の `ipc_feature` に `PIN_Auth` があれば PIN 登録に対応している
  - SSDP はマルチキャストの entitlement が必要なので使っていない。初回は iOS のローカルネットワーク許可が必要
- 見つからないときは IP アドレスを手入力する
- 使用中にテレビへつながらなくなったら（通信エラーのとき）、同じ方法で探し直し、保存済みの資格情報で認証が通ったテレビのアドレスに切り替える（DHCP でアドレスが変わった場合など）。電源が切れているだけのこともあるので、探し直しは 3 分に 1 回まで
- テレビを選ぶか IP アドレスを入力し、「テレビに PIN を表示」→ テレビに出た PIN を入力して登録する（レグザAppsコネクト v2 の `request_connection` / `confirm_connection`）
  - パスワードは PIN から作った鍵（PBKDF2-HMAC-SHA1, 1331 回）の AES-128-CBC で暗号化されて届く。Android でも動くよう SHA-1 / AES は `RegzaCore` で自前実装している
  - ユーザー ID はアプリ用に MAC アドレス形式のランダムな値を 1 つ作り、キーチェーンに保存して使い回す（iOS は本物の MAC アドレスを取得できない）。同じ ID で登録し直すとテレビ側で上書きされ、前のパスワードは無効になる。キーチェーンはアプリを削除しても残るので、入れ直しても登録は増えない
  - 手入力されたユーザー名は他のツールと共有しているかもしれないので、PIN 登録には使わない
  - 別のユーザー ID の登録は共存する（アプリと別のツールを別々の ID で登録し、両方で操作できることを実機で確認）。登録できる件数の上限と、テレビ側で登録を削除する方法は不明（取扱説明書に記載がない）
- PIN 登録に対応していない機種は、テレビの外部連携設定で決めたユーザー名・パスワードを手入力する
- 電源 ON をスマホから行うには、待機時の通信（クイック起動など）を有効にする

## 視聴状況の取得

- レグザAppsコネクト v2 API の `GET /v2/remote/play/status` を優先して使う（HTTP 80番で動作）
  - 放送: チャンネル名、番組の開始時刻・長さ、次の番組の開始時刻
  - 録画再生: 番組名、番組説明、再生位置、再生/一時停止
  - 外部入力 (HDMI)・待機中も判別できる
- v2 API が無い機種（404 など）では旧 API の `status.htm` に切り替える（録画再生中の情報のみ）
- 対応 API の一覧は `GET /v2/remote/support` で確認できる（HTTP 80 番では暗号化されて返る。HTTPS 4430 番なら JSON のまま読める）

## チャンネル一覧

- `GET /v2/remote/settings/channel_list` でテレビに登録されているチャンネルを取得し、地デジ・BS・CS ごとに並べる（種類は `ex_channel_number` の `DUV` / `DBS` / `DCS` で見分ける）
- 押すと `POST /v2/remote/status/channel`（フォーム `channel` にチャンネル一覧の `channel` の値）で直接選局する。成功すると `{"status":0}`、存在しないチャンネルは `{"status":1}`
- いま映っているチャンネルは `play/status` の `epg_info_current.channel` と照らし合わせて印を付ける

## 録画

- 録画予約: `GET /v2/remote/pvr/reserves/list`。連ドラ予約は次の回が番組表に載ると `start_time` と `title` がその回に更新され、それまでは最後に録画した回のまま残るので、「予定」と「次の回を待っている」に分けて出す
- 録画番組: v2 API には一覧がないので、テレビの DLNA サーバー（ポート 20003 の `ContentDirectory` の `Browse`、認証不要）を使う
  - テレビ側のフォルダ（ハードディスクごとの「すべて」「未視聴」「ジャンル別」など）をそのままたどれる。番組名・説明・ジャンル・長さ・未視聴（`regza:playbackState` が `0`）が取れる
  - 映像は DTCP-IP で保護されているのでアプリでは再生できない。DLNA の番組 ID は v2 API の再生用 ID（`rec_content_id`）と対応しないため、テレビでの再生も指定できず、録画リストを開くキーを送るだけにしている
  - ポートは固定で使っている（機種によって違う場合は SSDP で `MediaServer` の `LOCATION` を調べる必要がある）
- 番組表 `GET /v2/remote/epg/:channel_code?time=<Unix 秒>` は番組名・説明が空で返るため使っていない

## 制限

- 機種によっては v2 API が放送中の番組名・番組説明を空文字で返すため、放送中はチャンネル名と放送時間のみ表示する（`/v2/remote/epg/:channel_code` も同様）
- Live Activity は、アプリを開いている間は 2 秒ごとに更新される。閉じている間は次のときに更新される
  - Live Activity のボタンを押したとき
  - iOS がアプリを起こしたとき（BGAppRefreshTask。放送中は番組の終了時刻の後、それ以外は 15 分後以降で予約するが、実際にいつ起こされるかはシステム次第で、起こされないこともある）
  - 放送中は番組の終了時刻を staleDate にしているので、アプリが起こされなくても、その時刻に「番組が終わりました・次の番組 HH:mm〜」へ表示が切り替わる
- テレビ本体のリモコンでチャンネルを変えたことは、アプリを開くか iOS がアプリを起こすまで反映されない
- 確実に更新するには、家のサーバーからテレビの状態を見て ActivityKit のプッシュ通知を送る仕組みが必要（未実装）

## Android 展開（予定）

`RegzaCore` を Swift SDK for Android でビルドし、JNI 経由で Kotlin / Jetpack Compose の UI から呼ぶ。
接続情報の保存は `RegzaConnectionStore` を Android 側で実装する。
