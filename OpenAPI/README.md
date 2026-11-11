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

## REGZA の Swift クライアント

`Packages/RegzaCore` の `RegzaTVAPI` は、Apple の Swift OpenAPI Generator 1.14.4 で
`regza-tv.yaml` から型とクライアントをビルド時に生成する。仕様はこのファイルだけで管理し、
生成された Swift は `.build/` に置くのでコミットしない。設定は
`Packages/RegzaCore/Sources/RegzaTVAPI/openapi-generator-config.yaml`。

iOS・Android・macOS・Linux は同じ生成クライアントを使う。
生成型は Infrastructure の内部に閉じ、画面・Domain に公開する型は変えない。
Mirakurun・EPGStation の生成クライアントへの移行はまだ行っていない。

Repository が使う窓口の名前は `RegzaAPIClient`・`MirakurunAPIClient`・`EPGStationAPIClient` に揃える。
APIClient は API の操作をまとめ、Repository は Domain への変換・キャッシュ・保存を担当する。
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
`RegzaCompatibilityMiddleware` は、LenientJSON による本文補正と、欠けた Content-Type の補完を行う。
タイムアウトと録画予約の HTTPS 4430・自己署名証明書の扱いは既存の通信層に引き継ぐ。
旧 API の応答はバイト列で受け、既存の UTF-8・Shift_JIS・EUC-JP の判定を使う。
OpenAPI で表現できないシークの秒数だけのクエリは、互換ミドルウェアで Digest 署名の前に補う。

```sh
swift build --package-path Packages/RegzaCore --target RegzaTVAPI
```

通常の iOS アプリのビルドでも、仕様が変わると生成し直す。

Infrastructure の配置:

```text
API/
  Regza/
    RegzaAPIClient.swift
    RegzaAPIClient+Generated.swift
    RegzaConnectionState.swift
    RegzaDiscovery.swift
    RegzaPairing.swift
    RegzaRemote.swift
    Models/
    Middleware/
  Mirakurun/MirakurunAPIClient.swift
  EPGStation/EPGStationAPIClient.swift
Network/
  OpenAPIHTTPTransport.swift
  HTTPTransport.swift
  SocketTransport.swift
Repositories/
```

## ライセンス

- `mirakurun.json`: [Mirakurun](https://github.com/Chinachu/Mirakurun) (Chinachu Project) の Apache License 2.0。全文は `licenses/Mirakurun-LICENSE`
- `epgstation.json`: [EPGStation](https://github.com/l3tnun/EPGStation) (l3tnun) の MIT License。全文は `licenses/EPGStation-LICENSE`
