# 共通の文字列

文言は `iOS/RegzaKit/Sources/Localization/Resources/Localizable.xcstrings` で編集する。
iOSはSwift Packageの標準リソースとして読み込み、Android XMLと両OSの参照コードを生成する。
現在の元言語は日本語。今回の変更で新しい翻訳言語は追加しない。

```sh
mise run generate-localizations
mise run check-localizations
```

初回はルートで `mise install` を実行する。Bunの版と実行タスクはルートの `mise.toml` で管理し、追加のライブラリや翻訳サービスは不要。
変換処理はこのディレクトリの専用コードであり、XcodeやAndroidの標準生成機能ではない。
変換後のリソースのコンパイル・選択・書式処理は各OSの標準機能に任せる。

キーは `common_close`・`settings_title`・`server_searching` のように用途別のsnake_caseにする。
String Catalogに `extractionState: manual` を指定し、Androidでだけ使うキーも保持する。
Xcodeから翻訳を追加する場合は、元言語を含めて使う文字列の状態を `translated` にする。
`shouldTranslate: false` はAndroidの `translatable="false"` として元言語だけを出力する。

生成結果は以下のとおり。元ファイルと生成結果を一緒にGitへ含め、生成結果は直接編集しない。

- `iOS/RegzaKit/Sources/Localization/Generated/AppStrings.swift`
- `Android/core/localization/src/main/java/com/example/regzaremote/localization/Generated/AppStrings.kt`
- `Android/core/localization/src/main/res/values/app_strings.xml`（元言語・未翻訳時のフォールバック）
- `Android/core/localization/src/main/res/values-b+…/app_strings.xml`（追加した言語）

画面は `AppStrings.settingsTitle`、引数付きの文言は `AppStrings.serverSearching(name)` のように参照する。
iOSはLocalizationパッケージのBundle、Composeは `stringResource`・`pluralStringResource` を使用する。
Androidでは非Composableの処理やLazyListの構築コールバックへ入る前に文言を取得して渡す。

変換対象は通常の文字列、`%@`・`%lld`・`%d`・`%f` の引数、単一整数による複数形。
複数の引数は全て番号を付けるか、全て省略する。翻訳での番号による順序変更も扱う。
書式付き文章のパーセントは `%%`、文字列だけの末尾のパーセントは `%` のまま使える。
複数形は `other` を必須とし、Android標準の6分類へ出力する。
端末別・複雑なsubstitutionsなどは別キーに分ける。未対応形式・引数の数や型の違いはエラーにする。
改行・引用符・XML特殊文字・先頭末尾の空白は変換テストで確認する。

通常のアプリビルドでは生成せず、lintとCIで変換テストと生成結果の一致を確認する。
言語を削除した場合は専用の `app_strings.xml` だけを削除し、他のリソースを触らない。

## 共有のSwiftの文言

共有のSwift（`Packages/RegzaCore`）が画面に出す文言（リモコンのキー名・エラー・状態・メッセージ・日付の書き方など）も、同じString Catalogの `core_` で始まるキーに置く。
生成は次の2つ。`core_` のキーはOSの画面の `AppStrings` には出さない。

- `Packages/RegzaCore/Sources/RegzaStrings/Generated/CoreStrings.swift`（共有のSwiftが `CoreStrings.keyPower` のように引く。元言語の文言も持つ）
- `Android/core/localization/src/main/java/com/example/regzaremote/localization/Generated/CoreStringResources.kt`（キーとAndroidの文字列リソースの対応）

共有のSwiftはAndroidでも動き、アプリに入れた翻訳を自分では読めないので、OSが選ばれている言語の文言をまとめて入れる（`CoreStringTable.install`）。
iOSはアプリ（`AppContainer`）とウィジェットの拡張（WidgetBundle）がプロセスごとに `CoreStringsSetup.install()` を呼び、`Bundle` から入れる。
Androidは `RegzaApplication` が起動時と言語の変更時に、文字列リソースを `RegzaAndroidBridge.regzaUseStrings` で入れる。
入っていないとき（CLI・テスト・Android Studioのプレビュー）と、入れた中にないキーは元言語の文言を使う。
書式の引数はiOSの形（`%@`・`%lld`）とAndroidの形（`%1$s`・`%1$d`）のどちらからでも共有のSwiftが入れる。まとめて入れるので、`core_` のキーに複数形は使えない（生成時にエラーにする）。

日付と曜日の言語は `core_locale`、短い日付の書き方は `core_date_day_short` に置き、文言の言語と日付の書き方を揃える。

次は対象にしない。

- Siri・ショートカット・ウィジェットやコントロールセンターの表示名などのOS連携用メタデータ（App Intents・WidgetKitの仕組みで扱う）
- 番組検索の言葉の読み取り（「今日」「出演」など。翻訳ではなく、言語ごとに読み取り方を作る）
- テレビやサーバーから届く日本語のデータの読み取り（局名の地域名・番組説明の見出しなど）
- CLIや振る舞いのテスト向けの操作の説明、見本のデータ、開発用の表示
