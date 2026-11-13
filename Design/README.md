# デザイントークン

両 OS でそろえる余白・ボタンの高さ・角丸は `tokens.json` で管理する。
[DTCG 2025.10](https://www.designtokens.org/tr/2025.10/format/) の `$type`・`$value`・`$description` と寸法の形式を使い、
[Style Dictionary](https://styledictionary.com/) の標準フォーマットで Swift・Kotlin を生成する。
寸法の `px` は物理ピクセルではなく、iOS で同じ数値の pt (`CGFloat`)、Android で dp (`Dp`) として使う。
この設定の寸法トークンには `px` を指定する。
既存の `Design.outer` などの呼び出し方は変えない。

```sh
mise run generate-design-tokens
mise run check-design-tokens
```

生成するファイルは以下の 2 つ。JSON と生成結果を一緒に Git に含める。

- `iOS/RegzaKit/Sources/Design/Generated/Design.swift`
- `Android/app/src/main/java/com/example/regzaremote/design/Generated/Design.kt`

通常のアプリビルドでは生成処理を実行しない。`mise run lint` と CI の lint で
JSON と生成結果の不一致を検出する。生成ファイルは直接編集しない。
生成ファイルは lint・format の整形対象から外し、Style Dictionary の出力をそのまま保持する。
`generate.ts --check` はファイルを書き換えずに生成結果を比較する。

`outer` は画面端、`item` は同じまとまりの要素間、`group` はまとまり間の余白。
`primaryHeight`・`regularHeight`・`compactHeight` は操作の大きさごとの高さ、`cornerRadius` は共通の角丸。
同じ種類の項目を追加するときは JSON に定義を追加するだけでよい。
OS 標準の背景色・文字色・フォント・操作表現は各 OS に置く。

Style Dictionary の版は `package.json`、間接依存は `bun.lock` で固定する。
実行には既存の振る舞いテストと同じ版の Bun を使う (`mise.toml`)。
初回は `mise -C Design install` を実行する。生成・確認タスクは `bun install --frozen-lockfile` を先に実行する。
アプリの実行時依存には追加しない。
