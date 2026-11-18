# リポジトリの構成

フォルダの並びと、それぞれに置くもの。層とモジュールの関係は [architecture.md](architecture.md) にある。

## いちばん上

```
toolchains.toml・mise.toml・mise.linux.toml   設定ファイル（下の「設定ファイル」）
Packages/RegzaCore/      iOS と Android で共有する Swift Package
iOS/                     iOS 版
Android/                 Android 版
OpenAPI/                 外部の API の定義（ここから API クライアントを生成する）
Design/                  デザイントークン（色・余白の JSON。両 OS のコードを生成する）
Localization/            文言の生成ツール（定義元は iOS の String Catalog）
BehaviorTests/           振る舞いのテスト（Bun・TypeScript。iOS 側と Android 側に同じテストを流す）
UITests/                 画面のテスト（Maestro）と、そのための HTTP スタブ
Tools/                   開発の道具（モックの生成・ktlint の独自の規則）
scripts/                 道具の版を確かめるスクリプト
docs/                    このアプリによらない、設計と開発のドキュメント
.github/workflows/       CI（mise のタスクを流す）
```

## 共有の Swift（Packages/RegzaCore）

```
Sources/
  RegzaSharedModels/     画面に出す UI の型（iOS と Android で共有）
  RegzaDomain/           Data・Repository の約束・UseCase・SharedModel への変換
  RegzaTVAPI/ など       外部の API ごとの型とクライアント（ビルドのときに OpenAPI の定義から生成。設定は openapi-generator-config.yaml）
  RegzaInfrastructure/   API クライアントを使う Repository の実装・通信と保存の受け口・API の型から Data への変換
  Presentation/          ViewModel・State・Action（<モジュール>/<画面>/ に ViewModel・State/・Action/）
    PresentationCore/      共通
    <機能>Presentation/    機能ごと
    AppPresentation/       アプリ全体
  RegzaPresentation/     プレゼンテーション層をまとめて読み込み直すだけ（Android の窓口・組み立て・CLI・テスト用）
  RegzaApp/              組み立て（Factory）
  RegzaFakeServers/      偽物のサーバーと場面（プレビュー・振る舞いのテスト・CLI 用。リリース版には入らない）
  RegzaStrings/          共有の Swift が画面に出す文言の参照（生成）
  RegzaCLI/              ViewModel を画面なしで動かす CLI（regza）
Plugins/GenerateAPI/     API クライアントを生成するビルドのプラグイン
Tools/PrepareOpenAPI/    生成の前に、外部の API の定義を使う操作だけに整えるホスト用の道具
Tests/RegzaCoreTests/    共有の部分のテスト（Support/ にテストの準備、Generated/ に生成したモック）
```

## iOS（iOS/）

```
RegzaKit/                iOS だけで使う Swift Package。Sources/ は Android と同じく Core・Platform・UI に分ける
  Sources/Core/          Design（色と余白）・Localization（String Catalog と生成した参照）
  Sources/Platform/      AppServices・LiveActivity・SystemActions・Shortcuts・Widgets
  Sources/UI/            <機能>UI・UICommon（Preview/ にプレビューの準備）・AppUI
  Tests/RegzaKitTests/   iOS の部品のテスト（保存・終了時の処理・復元・文言）と、構成の決まりのテスト（LayerTests・ScreenNamingTests）
RegzaRemote/             アプリのターゲット（起動・RootView。依存を画面に渡し、終了の通知をアプリの組み立てに渡す）
RegzaRemoteWidget/       ウィジェット拡張のターゲット（Widgets を登録するだけ）
RegzaRemote.xcodeproj    アプリとウィジェット拡張（モジュールを組み立てるだけの薄い層。共有のスキームを含む）
Config/                  署名とバンドル ID
```

## Android（Android/）

```
core/bridge/             Swift の .so・窓口の Java のクラス・すべての送り先と state の Flow・Swift のビルド（buildSwift）
core/design/             色・余白・テーマ（デザイントークンから生成）と、通知とウィジェットで共通のアイコン
core/localization/       文言（String Catalog から生成した AppStrings と文字列リソース）
presentation/<名前>/     画面の状態と操作の型（共有の Swift のプレゼンテーションのモジュールと 1 対 1）
ui/common/               機能の画面が共通に使う部品とプレビューの準備（偽物での組み立ては debug のソースだけ）
ui/<機能>/               機能ごとの画面
ui/app/                  画面の組み立て
platform/appservices/    アプリの組み立て（プロセスに 1 つの窓口・画面の ViewModel の入れ物・保存先・通信）
platform/liveupdate/     ロック画面と通知の表示
platform/systemactions/  画面のない入口からキーを送る
platform/widgets/        ホーム画面のウィジェット
app/                     アプリ本体（起動だけ）
build-logic/             モジュールが共通に使うビルドの決まり（convention plugin）
gradle/libs.versions.toml  ライブラリと SDK の版（ここに 1 か所だけ書く）
RegzaAndroidBridge/      Android に見せる Swift の窓口（RegzaAndroidApp）。Mac・Linux の swift test で確かめる
RegzaAndroid/            Android 向けにビルドする Swift のパッケージ（Looper と、swift-java が作る Java のつなぎ）
ScreenGlue/              窓口のつなぎを作る道具（State/・Action/ を swift-syntax で読む。アプリには入らない）
behavior-tests/          振る舞いのテストの Android 側の相手（ホストの JVM で動く）
swiftkit-core/           swift-java の Java 側のライブラリ
scripts/                 Swift の .so と Java のクラスを作るスクリプト（build-swift.sh）など
mise.toml                設定ファイル（下の「設定ファイル」）
```

`settings.gradle.kts` が `presentation/`・`ui/`・`platform/` の下を読んで、モジュールを自動で足す。

## 作るもの（手で直さない）

| 作るもの | 置き場所 | 作り方 | Git に入れるか |
| --- | --- | --- | --- |
| API クライアント | `Packages/RegzaCore`（ビルドのときに作る） | Swift OpenAPI Generator（[OpenAPI/README.md](../OpenAPI/README.md)） | 入れない |
| 色・余白 | `iOS/RegzaKit/Sources/Core/Design/Generated/`・`Android/core/design/` | `mise run generate-design-tokens` | 入れる |
| 文言の参照 | `iOS/RegzaKit/Sources/Core/Localization/Generated/`・`Packages/RegzaCore/Sources/RegzaStrings/Generated/`・`Android/core/localization/` | `mise run generate-localizations` | 入れる |
| テスト用のモック | `Packages/RegzaCore/Tests/RegzaCoreTests/Generated/` | `mise run generate-mocks` | 入れる |
| Android の Swift のつなぎ | 開発ガイドの「[Android の Swift のビルド](development-guide.md#android-の-swift-のビルド)」の表 | Gradle の buildSwift（`Android/` の `mise run build-swift`） | 窓口の送る関数と設定の型の一覧だけ入れる（古いとテストが落ちる）。ほかは入れない |

## 設定ファイル

| ファイル | 役目 |
| --- | --- |
| `toolchains.toml` | Swift・Swift SDK for Android（とチェックサム）・Xcode の版（版の合わせ方は開発ガイドの「環境」） |
| `mise.toml`・`mise.linux.toml` | 共通の道具とタスク、Linux の Swift |
| `Android/mise.toml` | Android 用の Swift・JDK・SDK と専用のタスク |
| `UITests/mise.toml` | Maestro・JDK と、画面のテストの準備と実行 |
| `.swift-format` | Swift の書き方（行の長さ 140・インデント 4・`#if` の中は下げない） |
| `.editorconfig` | Kotlin の書き方（Android Studio の書き方・行の長さ 140・`@Composable` の関数は大文字始まりでよい） |
| `Android/gradle.properties` | Gradle の JVM のメモリ・同時ビルド |
| `iOS/Config/Signing.xcconfig` | 署名のチームとバンドル ID（手元の値は `Local.xcconfig`。Git に入れない） |
