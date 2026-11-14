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
- `Android/app/src/main/java/com/example/regzaremote/localization/Generated/AppStrings.kt`
- `Android/app/src/main/res/values/app_strings.xml`（元言語・未翻訳時のフォールバック）
- `Android/app/src/main/res/values-b+…/app_strings.xml`（追加した言語）

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

今回移すのは画面側の固定文言と、検索・予約確認など画面側で組み立てる文章。
共有Swiftの状態・エラー・リモコンキー名、日時や番組データ、Siri・Widget等のOS連携用メタデータは既存の定義を維持する。
これらも多言語化する場合は、共有コアの値やエラーの種類を各UIで文言へ変換する形を別途整える。
