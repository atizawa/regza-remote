# デザイントークン

両 OS でそろえる値は `tokens/` の JSON で管理する。

- `dimensions.json`: 余白・ボタンの高さ・角丸・縁の太さ。グループに `$type: dimension` を指定する。
- `colors.json`: ブランド色・リモコン配色。グループに `$type: color` を指定する。

[DTCG 2025.10](https://www.designtokens.org/tr/2025.10/format/) の `$type`・`$value`・`$description` と寸法・色の形式を使い、
[Style Dictionary](https://styledictionary.com/) の標準フォーマットで Swift・Kotlin を生成する。
寸法の `px` は物理ピクセルではなく、iOS で同じ数値の pt (`CGFloat`)、Android で dp (`Dp`) として使う。
この設定の寸法トークンには `px` を指定する。
寸法は `DesignDimensions.spacingOuter`・`DesignDimensions.buttonPrimaryHeight`、
色は `DesignColors.brandAccent`・`DesignColors.remotePower` のように種類と用途が分かる名前で使う。

```sh
mise run generate-design-tokens
mise run check-design-tokens
```

生成するファイルは以下の 4 つ。JSON と生成結果を一緒に Git に含める。

- `iOS/RegzaKit/Sources/Design/Generated/DesignDimensions.swift`
- `Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignDimensions.kt`
- `iOS/RegzaKit/Sources/Design/Generated/DesignColors.swift`
- `Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignColors.kt`

通常のアプリビルドでは生成処理を実行しない。`mise run lint` と CI の lint で
JSON と生成結果の不一致を検出する。生成ファイルは直接編集しない。
生成ファイルは lint・format の整形対象から外し、Style Dictionary の出力をそのまま保持する。
`generate.ts --check` はファイルを書き換えずに生成結果を比較する。

寸法は `spacing`・`button`・`shape`・`remoteControl` の用途ごとに分類する。
色は `brand`・`remote`・`remoteKey` の用途ごとに分類する。
グループに定義した型を、その中のトークンが継承する。
Style Dictionary の標準命名変換で、グループ名と項目名を組み合わせた定数を生成する。
色は sRGB の成分と透明度で定義する。両 OS の表現精度に応じた丸めは標準の変換処理に任せる。
`AppTheme`・`RemoteBody` は生成した色を各 OS のテーマやグラデーションに組み立てる。
同じ種類の項目を追加するときは JSON に定義を追加するだけでよい。
OS 標準の背景色・文字色・フォント・操作表現は各 OS に置く。

Style Dictionary の版は `package.json`、間接依存は `bun.lock` で固定する。
実行には既存の振る舞いテストと同じ版の Bun を使う (`mise.toml`)。
初回は `mise -C Design install` を実行する。生成・確認タスクは `bun install --frozen-lockfile` を先に実行する。
アプリの実行時依存には追加しない。
