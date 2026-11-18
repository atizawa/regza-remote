# REGZA リモコン

REGZA の HTTP リモコン API（[参考](https://misomayo.info/on/2012/04/10)）を使う iOS・Android のアプリ。
テレビの操作・いま映っているものの表示・チャンネル一覧と選局・録画予約に加え、録画サーバー（Mirakurun・EPGStation）と連携すると番組表とライブ視聴が使える。
対象は iOS 26 以上と Android 9（API 28）以上。

| ドキュメント | 内容 |
| --- | --- |
| [AGENTS.md](AGENTS.md) | 人と AI エージェントが守ること（言葉・入れてはいけないもの） |
| [docs/architecture.md](docs/architecture.md) | 層とモジュール、依存の向き、iOS と Android の対応、それぞれの理由、そろえない違い |
| [docs/repository-structure.md](docs/repository-structure.md) | フォルダの並び、生成物 |
| [docs/development-guide.md](docs/development-guide.md) | 環境、確かめ方、テスト、画面と機能の足し方、Android の Swift のビルド |
| [OpenAPI/README.md](OpenAPI/README.md) | 外部の API の定義と、API クライアントの生成 |
| [Design/README.md](Design/README.md) | デザイントークン（色・余白） |
| [Localization/README.md](Localization/README.md) | 文言（String Catalog） |
| [UITests/README.md](UITests/README.md) | 画面のテスト（Maestro）と HTTP スタブ |

動かし方は開発ガイドの「[初めてのとき](docs/development-guide.md#初めてのとき)」と「[ふだんの確かめ方](docs/development-guide.md#ふだんの確かめ方)」にある。

## できること

- 画面は「リモコン」（テレビを操作するボタン）と、見るための「番組表」「チャンネル」「録画予約」のタブに分けている。
  テレビで映っているものは、どのタブでもタブバーの上のミニプレーヤーに出し、押すと番組の詳細（録画ならシーク）を開く
- 録画番組の再生中は、番組名・再生位置を Dynamic Island とロック画面の Live Activity に出し、そこから音量・チャンネル・再生を操作できる
- REGZA だけでも、リモコン・Live Activity・Siri・チャンネル一覧と選局・録画予約の一覧・最初から見るが使える。
  Mirakurun（番組名・番組表・番組表からの予約）と EPGStation（ライブ視聴）は、設定の「録画サーバーとの連携」で設定した人だけが使う
  - 番組表のタブは未設定でも消さず（タブを出したり消したりしない HIG に合わせる）、何ができるかと設定のしかたを案内する
  - 連携は、それぞれの設定画面の「連携を解除」でやめられる
  - アドレスとポートは別々の欄で入れ、ポートが空なら標準のポート（Mirakurun 40772・EPGStation 8888）を使う。保存は `<アドレス>:<ポート>` の 1 つの文字列（ポートの欄が空なら `<アドレス>` だけ）
  - 「探す」と、同じサーバーの EPGStation の候補は、標準のポートだけを確かめる
  - EPGStation は Mirakurun から放送を受け取るので、ライブ視聴は Mirakurun を設定してから設定できるようにし（EPGStation だけでは番組名も出ず、見られない局も一覧に混ざる）、
    Mirakurun と同じサーバーで EPGStation が動いていれば候補として出す。Mirakurun の連携を解除すると EPGStation の連携も解除する
- テレビが未登録なら、タブの代わりに登録の案内を出す（設定は自動では開かない）
- 設定の「外観」で「システムに合わせる」「ライト」「ダーク」を選べる。初期値は OS に合わせ、選ぶとすぐに反映して保存する（テレビの接続の設定の保存・キャンセルとは別）

### 見た目

- 色は REGZA の公式サイトで使われている深い緑（`#00442D`）を基調にする（ライトでは `#006B4F`、ダークでは暗い背景でも見える明るめの `#1D866F`）。ロゴはまねしない
- 余白は 16 / 12 / 24、ボタンの高さは 56 / 48 / 40 の 3 段階だけを使い、色は選択中・進行中（緑）と電源・録画（赤）だけに使う
- リモコンのタブは、テレビ付属のリモコンの写真から測った色に合わせる。明るいグレーの本体にグレーのボタンと黒い文字、十字キーのあたりだけ黒い帯に黒いボタンと白い文字、
  銀色の決定、赤い電源ボタン。両方の外観で同じ配色にする

### iOS のウィジェット・コントロールセンター・Siri

- ホーム画面のリモコンのウィジェット（`RemoteWidget.swift`）
  - 中: 電源・入力切替・消音・チャンネルの上下・音量の上下
  - 大: 電源・入力切替・消音・地デジ/BS/CS・数字 1〜12・黒い帯に音量とチャンネルの上下・再生の段（10 秒戻し・再生・一時停止・30 秒送り）。
    数字を主役にするため、数字以外の段は低くそろえる。再生と一時停止は、ウィジェットからは今の状態が分からないので別々のボタン
  - 小は置けるボタンが少なく、同じ操作はコントロールセンターのボタンで足りるので出さない
  - 番組名などは出さず、ボタンだけを並べる（ウィジェットはすぐには更新されないので、今の番組は Live Activity に任せる）
- コントロールセンター・ロック画面・アクションボタンに置けるボタン（`ControlCenterControls.swift`）: 電源・消音・音量の上下・チャンネルの上下
- ウィジェットとコントロールセンターのボタンは `RegzaKeyIntent` でキーを送る。`LiveActivityIntent` なので、ウィジェットの拡張ではなくアプリのプロセスで動き、
  キーチェーンのテレビの登録情報をそのまま使える
- Siri・ショートカット（`RemoteIntents.swift`。言い方の登録はアプリのターゲットの `RegzaRemoteShortcuts`）
  - チャンネルを切り替える（`TuneChannelIntent`）: テレビのチャンネル一覧から局を選ぶ。全角・半角や「・」の違いを無視して局名で探すので、「NHK」でも「ＮＨＫ総合１・東京」に合う
  - テレビを操作する（`RemoteCommandIntent`）: 電源・音量・消音・チャンネルの上下・入力切替・再生・一時停止・停止・30 秒送り・10 秒戻し・録画リストを、回数を指定して押す
  - 「REGZAリモコンで NHK総合にして」「REGZAリモコンで消音」「REGZAリモコンでテレビをつけて」のように呼ぶ。チャンネル名の候補はアプリを開いたときにテレビの一覧で更新する
  - Siri の App Intent はふつうの `AppIntent` で、拡張にも登録すると拡張のプロセスで動くことがあるので、アプリにだけ登録する

### Android のウィジェット・通知

- iOS と同じ中・大のリモコンのウィジェットがある。先にアプリでテレビを登録し、Android 17 以降はローカルネットワークへのアクセスを許可してから、
  ホーム画面のウィジェットの一覧で「リモコン（中）」か「リモコン（大）」を追加する
  - 大きさを変えても種類とボタンの並びは変わらない。背景は置いた場所いっぱいに広げ、ボタンは縦横比を保って中央に置く
  - ボタン以外を押すとアプリを開き、ボタンはアプリを開かずにキーを送る。未設定・認証の失敗・通信の失敗はメッセージで知らせる
  - Jetpack Glance で描き、番組の取得や定期的な通信はしない。ボタンは画面のない入口（`:platform:systemactions`）から、保存済みの設定と共有の Swift でキーだけを送る。
    画面用の窓口は作らない（理由は [docs/architecture.md の「そろえない違い」](docs/architecture.md#そろえない違い)）
- 設定の「表示」か再生中の画面の「ロック画面と通知に表示」をオンにすると、iOS の Live Activity と同じ内容（番組名・チャンネル・進み具合・リモコンのボタン）を常駐の通知に出す
  - Android 16 以降は Live Updates として、ステータスバーのチップ（短い局名、録画中は「録画」）とロック画面の上にも出す
  - 通知のボタンは 3 つまでなので、放送中は CH−・CH＋・消音、録画は再生の操作、待機中は電源を出す
  - 残り時間（放送）と経過時間（録画）はシステムが進める時計で出し、進捗のバーはアプリが通知を更新したときに進む
  - 通知をスワイプで消すとオフになる。オンにするときに通知の権限を求め、通知やライブアップデートがオフなら設定を開く案内を出す
  - 番組の終了時刻の 30 秒後（放送でなければ 15 分後）に起こしてもらって取り直す。正確な時刻のアラームは使わない

## テレビ側の準備

- 設定画面の「テレビを探す」で同じネットワークの REGZA を検出する
  - 自分の /24 のアドレスすべてに `GET /public/feature`（認証不要）を並列に問い合わせ、`device_type` が `DTV` のものを候補にする。応答の `ipc_feature` に `PIN_Auth` があれば PIN 登録に対応している
  - SSDP はマルチキャストの entitlement が必要なので使っていない。初回は iOS のローカルネットワーク許可が必要
- 見つからないときは IP アドレスを手入力する
- 使用中にテレビへつながらなくなったら（通信エラーのとき）、同じ方法で探し直し、保存済みの資格情報で認証が通ったテレビのアドレスに切り替える（DHCP でアドレスが変わった場合など）。電源が切れているだけのこともあるので、探し直しは 3 分に 1 回まで
- テレビを選ぶか IP アドレスを入力し、「テレビに PIN を表示」→ テレビに出た PIN を入力して登録する（レグザAppsコネクト v2 の `request_connection` / `confirm_connection`）
  - パスワードは PIN から作った鍵（PBKDF2-HMAC-SHA1, 1331 回）の AES-128-CBC で暗号化されて届く。Android でも動くよう SHA-1 / AES は共有の Swift で自前実装している
  - ユーザー ID はアプリ用に MAC アドレス形式のランダムな値を 1 つ作り、キーチェーンに保存して使い回す（iOS は本物の MAC アドレスを取得できない）。同じ ID で登録し直すとテレビ側で上書きされ、前のパスワードは無効になる。キーチェーンはアプリを削除しても残るので、入れ直しても登録は増えない
  - 手入力されたユーザー名は他のツールと共有しているかもしれないので、PIN 登録には使わない
  - 別のユーザー ID の登録は共存する（アプリと別のツールを別々の ID で登録し、両方で操作できることを実機で確認）。登録できる件数の上限と、テレビ側で登録を削除する方法は不明（取扱説明書に記載がない）
- PIN 登録に対応していない機種は、テレビの外部連携設定で決めたユーザー名・パスワードを手入力する
- 電源 ON をスマホから行うには、待機時の通信（クイック起動など）を有効にする

## テレビとの通信

- Digest 認証は OS の認証チャレンジに頼らず、共有の Swift で自前実装して両 OS で使う
- 通常の HTTPS は各 OS の信頼ストアとホスト名の検証を使う。テレビの 4430 番だけは自己署名の証明書を受け入れ、その接続ではリダイレクトを追わない
- iOS の旧登録 ID の移行と、保存キー・値の形式を保つ

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
  - 番組表の画面は横に局、縦に時刻を並べ、ジャンルごとに色を分ける。日付のボタン（今日・明日・6(金) …。Mirakurun が番組表を持っている日まで）で日を選べる。今日は今の正時から 24 時間、ほかの日はその日の朝 4 時から次の日の朝 4 時まで（日本の番組表と同じく、深夜番組は前の日の続きとして 24〜27 時と書く）。同じリモコン番号のサブチャンネルは代表の局だけ出す
  - チャンネル一覧のカレンダーのボタンからは、その局だけの番組表（`?networkId=&serviceId=`、8 日分ほど）を開ける
  - 番組表のナビゲーションバーの虫眼鏡から開く検索（番組表を広く使うため、検索欄は番組表の上に置かず別の画面にする）は、読み込んだ全部の番組（1 週間分）の番組名・説明・番組内容・出演者から探す。全角半角・ひらがなカタカナ・大文字小文字は区別しない。番組名に入っていないときは「〇〇 が出演」「説明に「〇〇」」と見つかったわけを添える。打った言葉のうち、日付（今日・明日・土曜・11/7 など）・時間帯（朝・夜・深夜・ゴールデン・21時から など）・ジャンル名は条件として読み（「明日の夜のサッカー」→ 明日・18〜28 時・「サッカー」）、× で外せる。言葉の途中は読まない（「朝ドラ」「大河ドラマ」はそのまま探す）。「夜のニュース」のような番組名を探すときは「そのまま探す」で条件を読まずに探せる
  - 端末の AI（FoundationModels）で言葉を広げる（「SMAP」→ メンバーの名前）ことも試したが、端末のモデルは知識が少なく（別のグループのメンバーを答える、存在しない名前を作る）、1 回に 10 秒以上かかったため使っていない。クラウドのモデル（Private Cloud Compute）は iOS 27 以降で、Apple に申請する権限が要る
- Mirakurun が受信していない放送（CS など）は番組名が出ない

## ライブ視聴（EPGStation）

EPGStation が設定されていれば、放送中の番組をアプリで見られる（番組の詳細と視聴中の画面の「アプリで見る」）。家の Wi-Fi の中だけで使う。

再生画面は縦向きでは映像の下に今の番組の情報（Mirakurun の番組表から。30 秒ごとに更新）と局の一覧を出し、局を押すと前の配信を止めてその局の配信を頼み直す。局の一覧は Mirakurun が受信している局（＝ EPGStation で見られる局）の代表チャンネルだけで、地デジ/BS/CS の選択は番組表・チャンネルのタブと共有する。横向きでは映像だけを出す。iOS の映像の部分は標準のプレーヤーなので、全画面・ピクチャインピクチャ・AirPlay のボタンはそのまま使える。

- `GET /api/streams/live/:channelId/hls?mode=0` で配信を頼み、`/streamfiles/stream{番号}.m3u8` に映像の部分（.ts）が載ったら再生する（iOS は AVPlayerViewController、Android は ExoPlayer）。映像は H.264、音声は AAC で届く
- チャンネル ID は Mirakurun のサービス ID と同じ（`network_id × 100000 + service_id`）
- 見ている間は `PUT /api/streams/:id/keep` を 10 秒ごとに送り、閉じたら `DELETE /api/streams/:id` で止めてチューナーを空ける
- EPGStation は keep が途切れても配信を自動では止めない（160 秒待っても残った）。そのため、アプリが頼んだ配信の番号を覚えておき、強制終了などで止められなかったものは、次にアプリの画面を開いたとき・次に配信を頼むときに止める。終了するときにも止めてみる（iOS はアプリの終了で、待つのは 2 秒まで。Android は画面の ViewModel が片づけられるときで、待たずに送る）。止められなかったものは次に画面を開いたときに止める
- 配信が始まらなかったときは、利用者が選んだ場合だけ、準備できないまま残っている配信（ほかの端末のものも含む）を止めてからもう一度頼む
- 頼んでから再生できるまで 20 秒ほどかかる。同時に変換できる数に上限がある構成では、ほかで見ている配信があると始まらないことがある
- 画質は EPGStation の設定の最初のもの（mode 0）だけを使う
- ほかのアプリに移ったときの扱いは OS で違う（[docs/architecture.md の「そろえない違い」](docs/architecture.md#そろえない違い)）
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

## 制限

- 録画の再生を始めるなど、テレビの映像が切り替わっている最中に `play/status` を問い合わせると、テレビが再起動する機種がある（決定キーの 0.4 秒後の問い合わせで再起動し、決定キーだけでは起きないことを実機で確認）。決定・再生・停止・戻る・終了などのキーを送った後と、選局した後は 6 秒間問い合わせない（選局の直後に問い合わせると status 1 が返ることも実機で確認）
  - テレビ本体のリモコンで切り替えられたときにも重ならないよう、ふだんの 2 秒ごとの確認は旧 API（`status.htm`）で行う。旧 API は切り替えの最中に 0.2 秒おきに問い合わせても再起動しないことを実機で確認した。旧 API の値（再生状態・チャンネル・番組）が変わったら切り替え中とみなして 6 秒待ち、`play/status` は落ち着いているときに 15 秒に 1 回と、自分でキーを送った後だけにする。その間の再生位置は旧 API の値や経過時間で進める
  - 2 秒ごとの確認・キーを送った後の取り直し・Live Activity の更新が重なると、ほかの確認が見つけた切り替わりを見落として `play/status` を問い合わせ、テレビが応答しなくなることを実機で確認した。確認は 1 本ずつ行い、`play/status` の直前にも待ち時間の最中でないかを確かめる
  - テレビ本体のリモコンで放送のチャンネルを変えたことは、旧 API では分からないので、反映まで最大 15 秒ほどかかる
- 切り替え中は `play/status` が一時的に 404 を返す。一度でも v2 API で取れたテレビでは、404 が返っても旧 API（`status.htm`）に切り替えない
- 機種によっては v2 API が放送中の番組名・番組説明を空文字で返す（`/v2/remote/epg/:channel_code` も同様）。Mirakurun がなければ、チャンネル名と放送時間に、`play/status` のジャンル（`genre` の 4 桁の 16 進の 3 桁目が ARIB の大分類。`00a8` なら趣味・教育）を添えて表示する
- Live Activity は、アプリを開いている間は 2 秒ごとに更新される。閉じている間は次のときに更新される
  - Live Activity のボタンを押したとき
  - iOS がアプリを起こしたとき（BGAppRefreshTask。放送中は番組の終了時刻の後、それ以外は 15 分後以降で予約するが、実際にいつ起こされるかはシステム次第で、起こされないこともある）
  - 放送中は番組の終了時刻を staleDate にしているので、アプリが起こされなくても、その時刻に次の番組（`epg_info_next` の開始時刻・長さと、Mirakurun があれば番組名）の表示へ切り替わる。同じチャンネルを見続けている前提の予想なので、テレビ本体のリモコンでチャンネルを変えていたら、次にアプリが状態を取るまで違う番組が出る
- テレビ本体のリモコンでチャンネルを変えたことは、アプリを開くか iOS がアプリを起こすまで反映されない
- 確実に更新するには、家のサーバーからテレビの状態を見て ActivityKit のプッシュ通知を送る仕組みが必要（未実装）

## このアプリの開発用の手順

- Debug ビルドを起動引数 `-LiveHost <EPGStation のアドレス> -LiveChannel <チャンネルの ID>` で起動すると、すぐライブ視聴の再生画面を開く（実際に配信を頼むので、確かめたら EPGStation で配信を止める）
- バンドル ID は `com.example.RegzaRemote`、ウィジェットは `com.example.RegzaRemote.Widget`（手元の値で上書きする方法は開発ガイドの「[初めてのとき](docs/development-guide.md#初めてのとき)」）
- Android のウィジェットの一覧の見本の画像は、本番と同じ Glance の描画から作った中・大の PNG を使う。並びを変えたときは、専用のエミュレーターを指定して作り直す（接続中のほかの端末には入れない）

```sh
export ANDROID_SERIAL=emulator-5580
mise -C Android exec -- ./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
mise -C Android exec -- adb -s "$ANDROID_SERIAL" install -r app/build/outputs/apk/debug/app-debug.apk
mise -C Android exec -- adb -s "$ANDROID_SERIAL" install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
mise -C Android exec -- adb -s "$ANDROID_SERIAL" shell am instrument -w -e class 'com.example.regzaremote.RemoteWidgetTest#layoutsFollowIOSFamiliesAndKeepTheirKeysAfterResizing' -e exportWidgetPreviews true com.example.regzaremote.test/androidx.test.runner.AndroidJUnitRunner
for size in medium large; do
  mise -C Android exec -- adb -s "$ANDROID_SERIAL" exec-out run-as com.example.regzaremote cat "files/widget-previews/remote_widget_${size}_preview.png" > "Android/platform/widgets/src/main/res/drawable-nodpi/remote_widget_${size}_preview.png"
done
```
