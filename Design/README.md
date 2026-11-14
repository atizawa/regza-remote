# デザイントークン

両 OS でそろえる値は `tokens/` の JSON で管理する。

- `dimensions.json`: 余白・ボタンの高さ・角丸・縁の太さ。グループに `$type: dimension` を指定する。
- `colors/common.json`: 外観によらないリモコン本体・キーの配色。
- `colors/light.json`・`colors/dark.json`: 外観ごとのブランド色・背景・文字・操作色。同じ名前のトークンを両方に定義する。

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

JSON と生成結果を一緒に Git に含める。主な生成物は以下のとおり。

- `iOS/RegzaKit/Sources/Design/Generated/DesignDimensions.swift`
- `Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignDimensions.kt`
- `iOS/RegzaKit/Sources/Design/Generated/DesignColors.swift`
- `Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignColors.kt`
- `iOS/RegzaKit/Sources/Design/Generated/DesignColors.xcassets`: 各色のAny・Darkを含むColor Asset。
- `Android/app/src/main/res/values/design_colors.xml`: ライト用の標準色リソース。
- `Android/app/src/main/res/values-night/design_colors.xml`: ダーク用の標準色リソース。

Android XMLはStyle Dictionary標準の `android/colors` で生成する。
Color Assetへの配置は `generate.ts`・`color-assets.ts`、Swift・Kotlinのリソース参照は `formats.ts` の小さな専用処理で生成する。
Swiftはパッケージの `.module`、Composeは `colorResource` を使い、外観に応じた解決はOSに任せる。
`AppTheme` は色の値を持たず、標準リソースの色をテーマに適用する。
Color Assetの削除・改名も生成時に反映し、確認時は不要な生成物も検出する。
成分と透明度は必ず小数表記で出力する。例えば整数文字列 `"1"` はactoolに `1/255` と解釈されるため使わない。
この出力契約の回帰テストも `mise run check-design-tokens` とlintで実行する。

通常のアプリビルドでは生成処理を実行しない。`mise run lint` と CI の lint で
JSON と生成結果の不一致を検出する。生成ファイルは直接編集しない。
生成ファイルは lint・format の整形対象から外し、Style Dictionary の出力をそのまま保持する。
`generate.ts --check` はファイルを書き換えずに生成結果を比較する。

寸法は `spacing`・`button`・`shape`・`remoteControl` の用途ごとに分類する。
色は `brand`・`semantic`・`remote`・`remoteKey` の用途ごとに分類する。
グループに定義した型を、その中のトークンが継承する。
Style Dictionary の標準命名変換で、グループ名と項目名を組み合わせた定数を生成する。
色は sRGB の成分と透明度で定義する。両 OS の表現精度に応じた丸めは標準の変換処理に任せる。
`AppTheme`・`RemoteBody` は生成した色を各 OS のテーマやグラデーションに組み立てる。
同じ種類の項目を追加するときは JSON に定義を追加するだけでよい。
背景・文字・操作の共通色は `semantic` に定義し、OS標準のコントロールやフォント・操作表現は各OSに置く。
リモコン本体とLive Activityの暗い背景は実物の見た目や表示用途を保つため、両外観で共通にする。

Style Dictionary の版は `package.json`、間接依存は `bun.lock` で固定する。
実行には振る舞いテストと共通のBunを使う。版と実行タスクはルートの `mise.toml` で管理する。
初回はルートで `mise install` を実行する。生成・確認タスクは `bun install --frozen-lockfile` を先に実行する。
アプリの実行時依存には追加しない。
