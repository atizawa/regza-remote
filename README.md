# REGZA リモコン

REGZA の HTTP リモコン API（[参考](https://misomayo.info/on/2012/04/10)）を使う iOS アプリ。
録画番組の再生中は、番組名・再生位置を Dynamic Island / ロック画面の Live Activity に表示し、そこから音量・チャンネル・再生操作もできる。

iOS 26 以上が対象。画面はダークモードに固定している（Info.plist の `UIUserInterfaceStyle`）。テレビを見る暗い部屋でまぶしくないようにし、リモコンの配色とほかのタブの明るさをそろえるため。

画面は「リモコン」（テレビを操作するボタン）と、見るための「番組表」「チャンネル」「録画予約」のタブに分けている。テレビで映っているものは、どのタブでもタブバーの上のミニプレーヤー（`tabViewBottomAccessory`）に出し、押すと番組の詳細（録画ならシーク）を開く。色は REGZA の公式サイトで使われている深い緑（`#00442D`）を基調にしている（`AppTheme`。ダークモード固定なので、暗い背景でも見える明るめの `#1D866F` を使う）。ロゴはまねしない。

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

テレビや Mirakurun につながずに画面を確かめるときは、Debug ビルドを起動引数 `-SampleData YES` で起動すると見本データ（架空のチャンネルと番組）を表示する。`-SampleKind recorded` で録画再生中、`-InitialTab guide` / `channels` / `reservations` で最初に開くタブを選べる。`-InitialTab guide -SampleDetail YES` で放送中の番組の詳細を開く。`-LiveHost <EPGStation のアドレス> -LiveChannel <チャンネルの ID>` で、すぐ「iPhone で見る」の再生画面を開く（実際に配信を頼むので、確かめたら EPGStation で配信を止める）。

```sh
xcrun simctl launch booted com.example.RegzaRemote -SampleData YES -InitialTab guide
```

画面の余白・ボタンの高さ・色は `Design`（`RemoteControls.swift`）と `AppTheme` にまとめている。余白は 16 / 12 / 24、ボタンの高さは 56 / 48 / 40 の 3 段階だけを使い、色は選択中・進行中（緑）と電源・録画（赤）だけに使う。リモコンのタブは、テレビ付属のリモコンの写真から測った色に合わせ、グレーの本体に、十字キーのあたりだけ黒い帯、黒いボタンに白い文字、銀色の決定、赤い電源ボタンの配色（`RemoteBody`）にしている。

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

## 番組表（Mirakurun）

テレビの番組表 API は番組名を返さないので、Mirakurun（録画サーバー）が設定されていれば、そこから番組名と番組表を読む。設定画面で同じ /24 のポート 40772 に `GET /api/version` を問い合わせて探せる。認証は不要。

- テレビと Mirakurun は放送波の ID をそのまま使っているので、変換するだけで照らし合わせられる
  - チャンネル: テレビの `JP-G` + network_id + service_id（16 進 4 桁ずつ）。例: `JP-G7fe00400`
  - 番組: テレビの `epg_content_id`（`JP-0000` + network_id + service_id + event_id）→ Mirakurun の番組 ID `network_id × 10^10 + service_id × 10^5 + event_id`
- 放送中の番組名が空のときは `GET /api/programs/:id` で補い、アプリと Live Activity に出す。同じ番組は問い合わせ直さない
- `GET /api/programs`（全チャンネル分で数 MB）は 30 分に 1 回まで読み、チャンネル一覧の各局の今の番組名と、番組表の画面に使う
  - 番組表の画面は横に局、縦に時刻（今の正時から 24 時間）を並べ、ジャンルごとに色を分ける。同じリモコン番号のサブチャンネルは代表の局だけ出す
  - チャンネル一覧のカレンダーのボタンからは、その局だけの番組表（`?networkId=&serviceId=`、8 日分ほど）を開ける
- Mirakurun が受信していない放送（CS など）は番組名が出ない

## iPhone で見る（EPGStation）

EPGStation が設定されていれば、放送中の番組を iPhone で見られる（番組の詳細と視聴中の画面の「iPhone で見る」）。家の Wi-Fi の中だけで使う。

- `GET /api/streams/live/:channelId/hls?mode=0` で配信を頼み、`/streamfiles/stream{番号}.m3u8` に映像の部分（.ts）が載ったら iOS 標準のプレーヤー（AVPlayerViewController。ピクチャインピクチャ・AirPlay 対応）で再生する。映像は H.264、音声は AAC で届く
- チャンネル ID は Mirakurun のサービス ID と同じ（`network_id × 100000 + service_id`）
- 見ている間は `PUT /api/streams/:id/keep` を 10 秒ごとに送り、閉じたら `DELETE /api/streams/:id` で止めてチューナーを空ける
- EPGStation は keep が途切れても配信を自動では止めない（160 秒待っても残った）。そのため、アプリが頼んだ配信の番号を覚えておき、強制終了などで止められなかったものは、次にアプリを開いたとき・次に配信を頼むときに止める。終了するときも止めてみる
- 配信が始まらなかったときは、利用者が選んだ場合だけ、準備できないまま残っている配信（ほかの端末のものも含む）を止めてからもう一度頼む
- 頼んでから再生できるまで 20 秒ほどかかる。同時に変換できる数に上限がある構成では、ほかで見ている配信があると始まらないことがある
- 画質は EPGStation の設定の最初のもの（mode 0）だけを使う
- EPGStation で録画する機能は入れていない（録画先がテレビと EPGStation の 2 つになり、予約の画面が分かりにくくなるため）

## 録画

- 録画予約の追加: 番組表の番組の詳細から `POST /v2/remote/pvr/reserves/new`（フォーム `channel` `epg_content_id` `start_time` `duration`）で 1 回だけ予約する
  - HTTP（80 番）では内容によらず `{"status":2}` になり、HTTPS（4430 番）でだけ受け付ける。テレビの証明書は自己署名なので、4430 番への接続に限って受け入れている
  - `epg_content_id` は Mirakurun の network_id / service_id / event_id から組み立てる
- 連ドラ予約: 同じ API に `series_rec=true` だけを足して送る。繰り返し（毎週・月〜金など）とキーワードはテレビが番組から決める（`repeat_series` や `keyword_series` を自分で入れると `{"status":2}` になった）
- タイムシフトマシンの再生（`POST /v2/remote/timeshift/list/:channel_code`）と番組一覧（GET）は、値の形式が分からず使えていない（`{"status":1}` か `2` が返る）
- 最初から見る: リモコンの「始めにジャンプ」キーを送る。タイムシフトマシンで録画していない番組で押すとテレビにエラーが出るので、`GET /v2/remote/settings/timeshift` の対象の局（`target_channel`）と録画する時間帯（`active_time_list`。曜日ごとの 16 進の値の下位 24 ビットが 0〜23 時。例: 平日 19 時〜翌 1 時なら `00f80001`）から、番組の始まりから今までずっと録画しているときだけボタンを出す
- 録画予約の取り消し: `DELETE /v2/remote/pvr/reserves/list/:rsv_id`（HTTP で動く）。一覧の行を左にスワイプする
- 録画予約の一覧: `GET /v2/remote/pvr/reserves/list`。連ドラ予約は次の回が番組表に載ると `start_time` と `title` がその回に更新され、それまでは最後に録画した回のまま残るので、「予定」と「次の回を待っている」に分けて出す
- 録画番組の一覧は表示しない（リモコンの「録画リスト」キーでテレビの一覧を開く）
  - v2 API には一覧がない。テレビの DLNA サーバー（ポート 20003 の `ContentDirectory`）からは一覧を取れるが、映像は DTCP-IP で保護されているのでアプリでは再生できない
  - テレビで番組を指定して再生する `POST /v2/remote/pvr/play/list/:rec_storage_id/:rec_content_id` はあるが、DLNA の番組 ID（独自の `X_Toshiba_REGZA_Browse` も含む）から `rec_content_id` を求められなかった
- 番組表 `GET /v2/remote/epg/:channel_code?time=<Unix 秒>` は番組名・説明が空で返るため使っていない

## Siri・ショートカット

App Intents で次の操作を出している（`RemoteIntents.swift`。言い方の登録はアプリのターゲットの `RegzaRemoteShortcuts`）。

- チャンネルを切り替える（`TuneChannelIntent`）: テレビのチャンネル一覧から局を選ぶ。全角・半角や「・」の違いを無視して局名で探すので、「NHK」でも「ＮＨＫ総合１・東京」に合う
- テレビを操作する（`RemoteCommandIntent`）: 電源・音量・消音・チャンネルの上下・入力切替・再生・一時停止・停止・30 秒送り・10 秒戻し・録画リストを、回数を指定して押す
- Siri では「REGZAリモコンで NHK総合にして」「REGZAリモコンで消音」「REGZAリモコンでテレビをつけて」のように呼ぶ。チャンネル名の候補はアプリを開いたときにテレビの一覧で更新する

## 制限

- 録画の再生を始めるなど、テレビの映像が切り替わっている最中に `play/status` を問い合わせると、テレビが再起動する機種がある（決定キーの 0.4 秒後の問い合わせで再起動し、決定キーだけでは起きないことを実機で確認）。決定・再生・停止・戻る・終了などのキーを送った後は 6 秒間問い合わせない
  - テレビ本体のリモコンで切り替えられたときにも重ならないよう、ふだんの 2 秒ごとの確認は旧 API（`status.htm`）で行う。旧 API は切り替えの最中に 0.2 秒おきに問い合わせても再起動しないことを実機で確認した。旧 API の値（再生状態・チャンネル・番組）が変わったら切り替え中とみなして 6 秒待ち、`play/status` は落ち着いているときに 15 秒に 1 回と、自分でキーを送った後だけにする。その間の再生位置は旧 API の値や経過時間で進める
  - テレビ本体のリモコンで放送のチャンネルを変えたことは、旧 API では分からないので、反映まで最大 15 秒ほどかかる
- 切り替え中は `play/status` が一時的に 404 を返す。一度でも v2 API で取れたテレビでは、404 が返っても旧 API（`status.htm`）に切り替えない
- 機種によっては v2 API が放送中の番組名・番組説明を空文字で返すため、放送中はチャンネル名と放送時間のみ表示する（`/v2/remote/epg/:channel_code` も同様）
- Live Activity は、アプリを開いている間は 2 秒ごとに更新される。閉じている間は次のときに更新される
  - Live Activity のボタンを押したとき
  - iOS がアプリを起こしたとき（BGAppRefreshTask。放送中は番組の終了時刻の後、それ以外は 15 分後以降で予約するが、実際にいつ起こされるかはシステム次第で、起こされないこともある）
  - 放送中は番組の終了時刻を staleDate にしているので、アプリが起こされなくても、その時刻に次の番組（`epg_info_next` の開始時刻・長さと、Mirakurun があれば番組名）の表示へ切り替わる。同じチャンネルを見続けている前提の予想なので、テレビ本体のリモコンでチャンネルを変えていたら、次にアプリが状態を取るまで違う番組が出る
- テレビ本体のリモコンでチャンネルを変えたことは、アプリを開くか iOS がアプリを起こすまで反映されない
- 確実に更新するには、家のサーバーからテレビの状態を見て ActivityKit のプッシュ通知を送る仕組みが必要（未実装）

## Android 展開（予定）

`RegzaCore` を Swift SDK for Android でビルドし、JNI 経由で Kotlin / Jetpack Compose の UI から呼ぶ。
接続情報の保存は `RegzaConnectionStore` を Android 側で実装する。
