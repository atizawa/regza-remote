# OpenAPI

アプリがつなぐ外のサーバーの API の仕様。iOS・Android・共有の Swift のどれにも属さないので、ここにまとめる。

| ファイル | 相手 | 形式 | 出どころ |
|---|---|---|---|
| `regza-tv.yaml` | テレビ (REGZA) | OpenAPI 3.1 | 公式の資料がないので、実機での振る舞いから書き起こした |
| `mirakurun.json` | Mirakurun 4.0.0-beta.16 | Swagger 2.0 | 動いているサーバーの `/api/docs` の写し (2026-11-11 取得) |
| `epgstation.json` | EPGStation 2.10.0 | OpenAPI 3.0.1 | 動いているサーバーの `/api/docs` の写し (2026-11-11 取得) |

## 写しについて

- Mirakurun と EPGStation の仕様は、それぞれのソースの経路ごとの定義から、サーバーが起動したときに組み立てる。
  リポジトリの `api.yml` は枠だけなので、動いているサーバーから取る。
- 写しは、サーバーが返したものを整形しただけで、中身は変えていない。ただし `mirakurun.json` の `host` は、
  取ったサーバーのアドレスを例示用のアドレス (RFC 5737) に置き換えている。
- サーバーの版を上げたときは、取り直して版と日付をここに書く。

## Swift クライアント

Apple の Swift OpenAPI Generator 1.14.4 で、3 つの API の型とクライアントをビルド時に生成する。
取得した仕様の原本は変更せず、生成された Swift と中間仕様は `.build/` に置くのでコミットしない。
各モジュールの設定は `Packages/RegzaCore/Sources/<モジュール>/openapi-generator-config.yaml`。

| モジュール | 仕様 | 生成する操作 |
|---|---|---|
| `RegzaTVAPI` | `regza-tv.yaml` | 仕様にあるテレビの操作 |
| `MirakurunAPI` | `mirakurun.json` | バージョン・番組の一覧・1 番組 |
| `EPGStationAPI` | `epgstation.json` | バージョン・ライブ配信開始・配信一覧・keep・停止 |

`GenerateAPI` プラグインは、Mirakurun・EPGStation の仕様をホスト用ツール `Tools/PrepareOpenAPI` で
準備してから生成する。追加の Node.js や外部コマンドは不要。中間仕様はアプリの resource には含めない。

- Mirakurun の Swagger 2.0 は、使う 3 つの GET 操作のパラメーター・応答・参照を OpenAPI 3.0 に変換する。
  inline の path/query/header パラメーターを対象とし、body・collectionFormat 等の未対応形式はビルドを止める。
- EPGStation は使う操作を抽出し、原本にない operationId を付ける。
- 番組と配信一覧のモデルは、従来から読んでいた項目に絞る。未使用の映像・音声の enum 等で番組表が読めなくなるのを防ぐ。
- 従来の互換性として、番組の eventId・duration は省略可能にする。配信一覧では streamId のない項目を無視し、
  isEnable がなければ false とする。それ以外の型やパラメーターは原本の定義を使う。

iOS・Android・macOS・Linux は同じ生成クライアントを使う。
生成型は Infrastructure の内部に閉じ、画面・Domain に公開する型は変えない。
Mirakurun の生成 DTO は Domain 型に直接変換し、番組表全体の JSON 再エンコードはしない。

Repository が使う窓口の名前は `RegzaAPIClient`・`MirakurunAPIClient`・`EPGStationAPIClient` に揃える。
APIClient は接続設定・認証状態と共通の実行窓口 `request(_:)` を持つ。
Repository などの呼び出し元は `client.request(RegzaChannelsRequest())` のように Request を渡す。
操作ごとのメソッドは APIClient に追加しない。サーバー探索と配信準備の待機は専用の型に分ける。
Request は対応する Response 型と OpenAPI の型付き操作を定義し、Response は結果判定と Domain 型への変換を担当する。
同じ応答形式の操作は Response を共有する。本文を使わない操作には NoContentAPIResponse を使う。
パス・HTTP メソッド・シリアライズは OpenAPI の生成コードが担当し、Request 側に重ねて定義しない。
Repository は取得結果のキャッシュ・保存とアプリ用の状態管理を担当する。
APIClient は RegzaApp の組み立てで作り、Repository の initializer に注入する。
Repository は別の Repository を保持しない。番組表が設定済みかという配信条件は StreamUseCase が判断する。
テレビ用と録画用 Repository は、同じ RegzaAPIClient と RegzaConnectionState を共有する。
接続状態の世代番号でキャッシュを無効にし、接続変更前に始めた通信の結果を変更後の状態へ反映しない。
Mirakurun・EPGStation の接続先変更は、注入された通信方式とタイムアウトを保持した APIClient へ差し替える。
テレビの状態確認のタイミングを制御する `RegzaRemote` は、既存どおり Repository と RegzaAPIClient の間に置く。

`Network/OpenAPIHTTPTransport` は生成クライアントと既存の HTTPTransport の型を変換する。
iOS は URLSessionTransport、Android は SocketTransport + BoringSSL、テストは見本・偽物の通信をそのまま渡す。
HTTP のステータスとヘッダーは書き換えずに受け渡す。

Digest の再認証と nonce の管理は `RegzaDigestMiddleware` が担う。
`OpenAPIJSONMiddleware` は、3 つの API 共通で LenientJSON による本文補正と、欠けた Content-Type の補完を行う。
`OpenAPIResponseMiddleware` は HTTP エラーをアプリのエラーへ変換する。
401 を認証エラーとして扱うのは Digest 認証を使う REGZA だけとし、録画サーバーでは従来どおり HTTP ステータスを保持する。
タイムアウトと録画予約の HTTPS 4430・自己署名証明書の扱いは既存の通信層に引き継ぐ。
旧 API の応答はバイト列で受け、既存の UTF-8・Shift_JIS・EUC-JP の判定を使う。
OpenAPI で表現できないシークの秒数だけのクエリは、互換ミドルウェアで Digest 署名の前に補う。
EPGStation の `/streamfiles/*.m3u8` は REST API の仕様外のファイルなので、既存の HTTPTransport で取得する。

```sh
swift build --package-path Packages/RegzaCore --target RegzaTVAPI
swift build --package-path Packages/RegzaCore --target MirakurunAPI
swift build --package-path Packages/RegzaCore --target EPGStationAPI
```

通常の iOS アプリのビルドでも、仕様が変わると生成し直す。

Infrastructure の配置:

```text
API/
  Regza/
    RegzaAPIClient.swift
    RegzaAPIRequest.swift
    Requests/
    Responses/
    RegzaConnectionState.swift
    RegzaDiscovery.swift
    RegzaPairing.swift
    RegzaRemote.swift
    Models/
    Middleware/
  Mirakurun/
    MirakurunAPIClient.swift
    MirakurunDiscovery.swift
    MirakurunAPIRequest.swift
    Requests/
    Responses/
  EPGStation/
    EPGStationAPIClient.swift
    EPGStationDiscovery.swift
    EPGStationStreaming.swift
    EPGStationAPIRequest.swift
    Requests/
    Responses/
Network/
  APIRequest.swift
  APIResponse.swift
  NoContentAPIResponse.swift
  OpenAPIHTTPTransport.swift
  OpenAPIMiddleware.swift
  HTTPTransport.swift
  SocketTransport.swift
Repositories/
```

## ライセンス

- `mirakurun.json`: [Mirakurun](https://github.com/Chinachu/Mirakurun) (Chinachu Project) の Apache License 2.0。全文は `licenses/Mirakurun-LICENSE`
- `epgstation.json`: [EPGStation](https://github.com/l3tnun/EPGStation) (l3tnun) の MIT License。全文は `licenses/EPGStation-LICENSE`
