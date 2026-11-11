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

## ライセンス

- `mirakurun.json`: [Mirakurun](https://github.com/Chinachu/Mirakurun) (Chinachu Project) の Apache License 2.0。全文は `licenses/Mirakurun-LICENSE`
- `epgstation.json`: [EPGStation](https://github.com/l3tnun/EPGStation) (l3tnun) の MIT License。全文は `licenses/EPGStation-LICENSE`
