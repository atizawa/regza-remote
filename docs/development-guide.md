# 開発ガイド

環境の準備・ふだんの確かめ方・テスト・画面と機能の足し方・Android の Swift のビルドの調べ方。
構成の考え方は [architecture.md](architecture.md)、フォルダの並びは [repository-structure.md](repository-structure.md) にある。

## 環境

- Android の APK のビルドとホストの JVM のテストは macOS と Linux（Linux は Android NDK のホストの道具に合わせて x86_64）。
  iOS のビルドと iOS の部品のテストは Xcode が要るので macOS。Windows はそのままでは使えず、WSL2 で Linux の手順を使う
- 道具とタスクは mise で管理し、ふだんはリポジトリのルートで `mise run <タスク>` を流す。初めてのときの手順は下の「初めてのとき」
- Swift と Xcode の版は `toolchains.toml` に 1 か所だけ書く
  - `swift.version` は Android・Linux の swift.org 版と Swift SDK for Android の版、`swift.android_sdk_checksum` はその SDK のチェックサム、
    `xcode.version` は iOS に使う Xcode の版
  - iOS は Xcode に付いている Apple Swift を使い、`swift.version` と major.minor が同じことを確かめる（例: Apple Swift 6.4 と swift.org 6.4.2）。
    Android・Linux はリリースのタグまで一致させる。Xcode の `SWIFT_VERSION = 6.0` は言語モードで、コンパイラの版とは別
  - 選んでいる Xcode と Swift は `mise run check-apple-toolchain`（Linux は `mise run check-swift-toolchain`）で確かめる。iOS のテストとビルドの前にも動き、合わなければ止まる
  - 版を上げるときは、`toolchains.toml` で Xcode・Swift・SDK のチェックサムの組み合わせを直し、両方の環境でテストとビルドを確かめる
- Android SDK の場所は `ANDROID_HOME`、次に `ANDROID_SDK_ROOT` を見る。どちらもなければ macOS は `~/Library/Android/sdk`、Linux は `~/Android/Sdk`。
  SDK・NDK は開発しているマシン用、APK に入れる Swift の .so は Android の arm64-v8a 用で、この 2 つは別に扱う
- Swift の Android 向けのビルドは初回にメモリを多く使うので、同時に動かす数を既定で 2 にしている（`SWIFT_BUILD_JOBS=1 mise run build-android` で変えられる。CI の Android のジョブは 4）

### 初めてのとき

```sh
mise trust --all                          # ルート・Android/・UITests/ の設定をまとめて信頼する
mise install
cd Android
mise install                              # Swift のツールチェーン・JDK・Android CLI
mise run setup-android-sdk                # Android SDK のライセンスを確かめて同意する（Android Studio で SDK を入れていれば要らない）
mise run install-android-swift-sdk        # Swift SDK for Android（platform・build-tools・NDK は Gradle が入れる）
mise run prepare-android-preview          # Android Studio のエディタの横にプレビューを出すとき（ホスト向けのライブラリを作る）
```

iOS を実機に入れるときは、`iOS/Config/Signing.xcconfig` は変えずに、同じフォルダに `Local.xcconfig` を作って手元の値で上書きする（Git に入れない）。

```
// iOS/Config/Local.xcconfig
BUNDLE_ID_PREFIX = com.yourname
DEVELOPMENT_TEAM = ABCDE12345
```

## ふだんの確かめ方

```sh
mise run check                             # 全部を順に確かめる（CI と同じ。iOS のビルドを含むので macOS 用）
mise run lint                              # Swift と Kotlin の書き方・Android の依存の向き（直すときは mise run format）
mise run test-swift                        # Swift のパッケージのテスト（test-swift-shared と test-swift-apple）
mise run test-swift-shared                 #   Apple の環境がなくても流せるもの（Linux でも流す）
mise run test-swift-apple                  #   Xcode が要るもの（iOS の部品と構成の決まり）
mise run build-ios                         # iOS のアプリとウィジェットのビルド（Debug）
mise run check-ios-release                 # Release でもビルドし、リリース版に偽物とプレビューが入っていないことを確かめる
mise run build-android                     # Android のアプリとテスト APK のビルド（debug・release。release は APK の中身も確かめる）
mise run test-behavior                     # 振る舞いのテスト（iOS 側と Android 側）
```

端末が要るもの（`test-android-runtime`・`test-ui-ios`・`test-ui-android`）は `check` に入れていない。

### 変えたものごとの確かめ方

| 変えたもの | タスク |
| --- | --- |
| どれでも | `lint` |
| 共有の Swift | `check`（共有の型を変えると iOS と Android の画面のビルドも変わり、Android のつなぎも作り直すため。Linux では下の 4 つ） |
| デザイントークン・文言 | `generate-design-tokens`・`generate-localizations` で作り直してから `lint`（`lint` は生成物が元と合っているかも確かめる） |
| iOS | `test-swift-apple`・`check-ios-release` |
| Android | `build-android` |
| Android の Swift のつなぎ・通信・.so | `build-android`・`test-behavior`・`test-android-runtime`（端末があるとき） |
| 画面の移り変わり・設定・復元 | 上に加えて `test-ui-ios`・`test-ui-android` |

### Linux と CI

Linux では `MISE_ENV=linux` を付けて（`mise.linux.toml` を読み込み、共通の設定の Swift を入れる）、`check` の代わりに
`lint`・`test-swift-shared`・`build-android`・`test-behavior` を 1 つずつ流す。

main への push と pull request で、CI（`.github/workflows/check.yml`）が同じタスクを流す（ほかのブランチへの push だけでは流れない）。書き方と `test-swift-shared` は Linux、
`test-swift-apple`・`check-ios-release` は macOS で流す。`build-android` と `test-behavior` は Linux x86_64 で、初回の Swift のビルドに時間がかかるため、
CI の画面から手で動かしたとき（Run workflow）だけ流す。CI は Swift のビルドを取っておき、差分だけをビルドする。うまく動かないときは、
Actions の Caches から `swift-tools-`・`swift-android-` で始まるものを消す。
CI だけで使うタスクは `select-ci-xcode`（共通の設定の Xcode を選ぶ）。CI も手元と同じ `install-android-swift-sdk` で Swift SDK for Android を入れる（指定の版があれば入れ直さない）。
`lint` は、書き方のほかに、デザイントークンと文言の生成物が元と合っていること（`check-design-tokens`・`check-localizations`）と、
画面のテストの HTTP スタブの返事が API の定義に合うこと（`check-ui-stub`）も確かめる。

## 書き方

- Swift は swift-format（設定は `.swift-format`）、Kotlin は ktlint（設定は `.editorconfig`。Android Studio もこの設定で整形する）でそろえる。
  `mise run lint` で確かめ、`mise run format` で直す。道具が作るファイル（`Generated/`・`.build/`）は対象にしない
- 道具（`ktlint -F`・`swift format`）を直接広い範囲にかけると、生成したファイルも書き換わる。変えたファイルだけにかけるか、`mise run format` を使う
- 複数行に並べたものは、Kotlin では宣言でも呼び出しでも末尾にコンマを付け、Swift では配列と辞書にだけ付ける
  （swift-format の「必ず付ける」は閉じかっこの前に `, )` を残す不具合があるため使わない）
- 生成したファイルは手で直さず、元を直して生成し直す（作るものと作り方は [repository-structure.md](repository-structure.md#作るもの手で直さない)）。コメントの決まりは [AGENTS.md](../AGENTS.md) にある

## テスト

| 種類 | 何を確かめるか | 流し方 |
| --- | --- | --- |
| 単体のテスト | Repository・UseCase・ViewModel | `mise run test-swift-shared` |
| 契約のテスト | 偽物のサーバーの返事を本物の API クライアントで読めること・API の定義のどの操作にも答えること | 同上（`FakeServersContractTests`） |
| 構成の決まりのテスト | 依存の向き・画面の名前（iOS の部品と Android のフォルダ） | `mise run test-swift-apple`（`LayerTests`・`ScreenNamingTests`） |
| 振る舞いのテスト | 画面を描かずに、ViewModel の state と操作を iOS 側と Android 側で同じように確かめる | `mise run test-behavior` |
| 画面のテスト | 設定の入力・画面の移り変わり・入力の復元・外観の切り替えを、実際の画面で | `mise run test-ui-ios`・`test-ui-android`（[UITests/README.md](../UITests/README.md)） |
| 端末のテスト | Android の .so・JNI・Looper・通信・TLS・state の購読・復元・ウィジェット・通知 | `mise run test-android-runtime` |
| リリース版の検査 | リリース版に偽物とプレビューが入っていないこと（Android は手元のフォルダの場所も） | `check-ios-release`・`build-android` |

### 単体のテスト

- Repository と UseCase のモックは Mockolo で生成する。対象はドメインの `@mockable` を付けた protocol。protocol を変えたら `mise run generate-mocks`。
  Mockolo は `Tools/GenerateMocks/Package.swift` で版を固定し、アプリの依存から分けている
- `Tests/RegzaCoreTests/Support` は、入力の値（`DataFixtures.swift`）・モックの初期値（`RepositoryMocks.swift`）・
  通信と保存と本番の Factory をつなぐもの（`HTTPTestEnvironment.swift`）・ViewModel の準備と待機（`ViewModelFixtures.swift`）に分ける
- 戻り値やエラーはモックの Handler に入れ、呼ばれた回数と引数は生成された記録で確かめる。通信を含むテストは、本物の Repository と偽の HTTP を使う

### 振る舞いのテスト

画面を描かずに、ViewModel の state と操作を確かめる（Shopify の [Reflex](https://shopify.engineering/reflex) と同じ作り）。

- テストは `BehaviorTests/`（Bun・TypeScript）に 1 回だけ書き、iOS 側と Android 側の 2 つの相手に同じテストを流す。片方だけ通る状態は失敗になる
- テストは相手がどちらかを知らず、CLI と同じ約束事（`tree`・`ls`・`do`・`wait` の 1 行ずつの命令と JSON）だけを使う
  - iOS 側の相手は `regza`（iOS と同じ共有の組み立てを、Mac・Linux の CLI で動かす）
  - Android 側の相手は `regza-android`（`Android/behavior-tests`。ホストの JVM）。命令の読み方と JSON は同じものを使い、
    操作を送るところと state を受け取るところだけを、アプリと同じ道（Kotlin の送り先 → swift-java のつなぎ → 窓口）で行う。エミュレーターは使わない
- 外からの入力は偽物のサーバーで渡す。場面（`FakeScenario`）を名前で選び、1 つのテストだけの差し替えは宛先ごとの返事とつながらないアドレスで足す
- テストは `sdk/app.ts` の `describeOnBothPlatforms` で書き、`do`（操作を送り、state が期待どおりになるまで待つ）と
  `precondition`（state が期待どおりになるまで待つ）で確かめる
- Android の Foundation も iOS と同じ swift-foundation を土台にしているので、Mac で動かしても大半は Android と同じものを通る。
  Android の土台（ART と JNI・Bionic・Looper の MainActor・APK の中の .so）は端末のテストで確かめる

### 端末のテスト（Android）

Android API 28 以上の arm64-v8a の端末（エミュレーターか実機）が要る。外部のサーバーにはつながない。

```sh
(cd Android && mise exec -- adb devices -l)  # 対象が device と出ることを確かめる
mise run test-android-runtime
ANDROID_SERIAL=emulator-5554 mise run test-android-runtime   # 端末が何台もあるとき
```

- 画面を出すテストは、端末のロックを解除して画面を点けたままにしてから流す（`ScreenTestRule` が画面を点け、ロックが外せなければ理由を出して落とす）。
  Android 17 以降は、ローカルネットワークへのアクセスも先に許可しておく
- Gradle の `connectedDebugAndroidTest` は、終わるとアプリを端末から消し、保存先も書き換える。ふだん使っている端末では、登録した設定がなくなる
- Swift と Java の接続コード・state の待機とキャンセル・Looper・通信の実装・.so の梱包・Swift や swift-java や NDK の版を変えたときに流す

| テスト | 確かめること |
| --- | --- |
| `AndroidRuntimeSmokeTest` | APK の .so の読み込み、JNI・Looper を通る state の更新、Flow を止めたあとの待機の解消、一方の Flow を止めてももう一方に届くこと |
| `StateLifecycleTest` | 画面の Lifecycle が下がると待機が終わり、戻ると最新の state を受け取ること |
| `StateRestorationTest` | Activity を作り直しても入力が残ること、保存した Bundle から別の ViewModel に戻せること |
| `OkHttpTransportTest` | Swift → JNI → OkHttp で、分割の応答・gzip・クエリ・リダイレクト・時間切れ・取り消し |
| `TLSTransportTest` | 端末の中の TLS サーバーとの送受信、信頼されない証明書とホスト名の不一致を拒むこと、自己署名を受け入れる例外の範囲 |
| `RemoteWidgetTest` | ウィジェットの登録・キーの並び・大きさを変えたあとの表示、ボタンから保存済みの設定と通信を通してキーを送ること |
| `LiveUpdateNotificationTest` | ロック画面と通知の表示 |
| `ColorAppearanceTest`・`LocalizationResourceTest` | 外観に合わせた色、文字列リソース |
| `FoundationICUTest` | 絞った ICU の結果が、ICU をすべて持つ Apple の環境と同じこと（確かめる処理は debug の APK にだけ入る .so にある） |

| 失敗した場所 | 確かめる先 |
| --- | --- |
| 端末が見つからない・入れられない | `adb devices -l` の状態、USB デバッグの認証、端末の API と ABI。何台もあるときは `ANDROID_SERIAL` |
| 生成・native のビルド・梱包 | ビルドのログの `[build-swift]`（下の「Android の Swift のビルド」） |
| テストの失敗・時間切れ | `Android/app/build/reports/androidTests/connected/debug/index.html` と `Android/app/build/outputs/androidTest-results/connected/debug/` |
| アプリが落ちる・native のライブラリを読めない | `adb logcat -d -b crash`（何台もあるときは `adb -s <シリアル番号> logcat -d -b crash`） |

### 手で確かめること

- 画面の復元: 設定の入力を保存せずに、開発者向けオプションの「アクティビティを保存しない」をオンにしてホームへ移り、履歴から戻って入力が残ることを確かめる。
  プロセスの終了も確かめるときは、このオプションを戻してアプリを裏に回し、`adb shell am kill <アプリの ID>` で止め、
  `adb shell pidof <アプリの ID>` で止まったことを確かめてから履歴で戻る
- 偽物を入れずにアプリを起動して確かめるときは、画面のテストの HTTP スタブ（`UITests/server.ts`）を起動し、Debug ビルドに起動引数 `-UITestServer <スタブのアドレス>` を渡す

## 画面を足す

手で書くのは共有の ViewModel と、OS ごとの画面だけ（Android のつなぎは道具が作る）。守る決まりは [architecture.md](architecture.md) の
「画面の状態と操作」「画面の移り変わり」「依存の向き」にあり、ここには置き場所と手順だけを書く。

### 1. 共有の ViewModel を作る

`Packages/RegzaCore/Sources/Presentation/<機能>Presentation/<画面>/` に置く。新しい機能なら、`<機能>Presentation/` を作って `Package.swift` の
`presentationFeatures` に足し、アプリ全体の ViewModel から作る。

```
<機能>Presentation/<画面>/
├── <画面>ViewModel.swift       ViewModel
├── State/<画面>State.swift     画面に出すもの
└── Action/<画面>Action.swift   画面からの操作
```

- ViewModel は `@MainActor @Observable public final class` にし、`public typealias State = <画面>State` と `public typealias Action = <画面>Action` を書く。
  道具はこの 2 行で、どの ViewModel にどの型を送るかを決める
- State/ と Action/ には 1 つのファイルに 1 つの型を置き、名前は画面の名前で始める（State の中で使う enum も State/ に置く）。ここに置いた型だけが Java のクラスになる
- ViewModel のドメインを使う init やプロパティは `package` にする。State と Action の public なプロパティには型を書く（書いていなければ道具が止まる）
- 部品に分けた ViewModel には `typealias Action` を書かない（書くと Android から直接送れてしまう）
- `IntrospectableActions` にして `action(_:_:)` を書く。state を要約したり伏せたりするときは `introspectionJSON(of:)` に書く
- 画面の復元に保存するものは `<画面>RestorationState` として機能に置く
- テストを `Tests/RegzaCoreTests/RegzaPresentation/ViewModels/` に足す

### 2. アプリ全体から開けるようにする

- タブの最初の画面なら、アプリ全体の ViewModel に持たせて、開いている ViewModel の並びに足す
- タブの中で開く画面なら、戻る道の型（`AppRoute`）に case と `id` を足し、`AppViewModel.viewModel(for:)` でその ViewModel を返す
- 機能の画面からは `AppNavigator` の `push(route)` などで開く

### 3. iOS の画面を作る

- `iOS/RegzaKit/Sources/UI/<機能>UI/<画面>Screen.swift` に `package struct <画面>Screen` として置き、`viewModel.state` を見て `viewModel.send(...)` で送る
- プレビューはファイルの末尾の `#if DEBUG` の中に `FakePreview` で置く。機能の画面は `NavigationStack` を持たないので、プレビューでは `NavigationStack { ... }` で包む
- 画面の移り変わりは環境値 `appNavigator` に頼む。ほかの機能の ViewModel が要るときは、組み立て（`AppUI` の `AppScreen`・`AppRoutes`）が引数で渡す
- 新しい機能なら、`Sources/UI/<機能>UI/` を作り、`Package.swift` の `features` に足す（`LayerTests` がフォルダと `features` の一致を確かめる）。
  機能の画面はそれぞれライブラリのプロダクトなので、Xcode がスキーム（`<機能>UI`）を作る。プレビューはそのスキームで開くと速い

### 4. Android の画面を作る

- Android のビルド（`./gradlew` の buildSwift）が毎回つなぎを作り直す（作るものは下の「Android の Swift のビルド」の表）。Git に入れるものが古いと
  `Android/ScreenGlue` のテスト `committedGlueIsUpToDate` が落ちるので、作り直したものをコミットする。つなぎだけを作り直すときは、`Android/` で
  `swift run --package-path ScreenGlue --scratch-path .build/screen-glue -c release screen-glue`
- 画面は `Android/ui/<機能>` の package `com.example.regzaremote.ui.<機能>` に `<画面>Screen.kt` として `fun <画面>Screen(` を置き、
  自分の state と送り先（`<機能>Send`）を受け取って描き、`send(...)` で送る（移り変わりは `send.push(route)` など）
- プレビューはファイルの末尾に `FakePreview<<機能>App>(setUp = { ... }) { app -> ... }` で置く。戻る道の画面に要るデータを先に読むときは `prepareRoutes = true`
  - エディタの横のプレビューはホストの JVM で描くので、先に `mise run prepare-android-preview` でホスト向けのライブラリを作る（macOS は .dylib、Linux は .so）。
    「Run Preview」はエミュレーターで、アプリと同じ Android 向けのライブラリを使う
  - 偽物は debug にだけあるので、プレビューは debug のビルドの種類でだけ出せる。Swift の型はライブラリを読み込んだあと（`setUp` と中身）で作る
- タブの最初の画面なら組み立ての `AppRoutes.kt` の `TabRoot`、タブの中で開く画面なら同じファイルの `RouteScreen` に足す
- 新しい機能なら、`Android/presentation/<機能>/build.gradle.kts`（`plugins { id("regza.android.presentation") }`）と
  `Android/ui/<機能>/build.gradle.kts`（`plugins { id("regza.android.ui") }`）を置く。`settings.gradle.kts` が自動で足す
- いくつもの機能で使う部品は `:ui:common` の `ui/components` に置く
- 色・テーマ・余白は `:core:design` にある（`AppTheme.kt`・`AppearanceTheme.kt`。色と余白の値は `Generated/` にデザイントークンから生成する）

### 5. 確かめる

`mise run check` を流し、`BehaviorTests/tests/` にその画面の振る舞いのテストを足す（操作を送り、state が期待どおりになるまで待つ）。
両方のプレビューと、画面の移り変わりを実機かシミュレーターで確かめる。

## Android の Swift のビルド

入口は `Android/` の `./gradlew :app:assembleDebug`（中で `scripts/build-swift.sh` を流す）。NDK の版は Gradle、Swift と SDK の版は `toolchains.toml`、
Java のパッケージなどは `RegzaAndroid/swift-java.common.config` を見る。以下のパスは `Android/` からのもの。

| 段階 | 入力・設定 | 出力 |
| --- | --- | --- |
| 共有の UI の型の Java の生成 | `../Packages/RegzaCore/Sources/RegzaSharedModels`、swift-java の共通の設定 | `.build/swift/regzashared-java/`、`RegzaAndroid/Sources/RegzaSharedJava/Generated/` |
| 画面の型の Java の生成 | プレゼンテーション層の State/・Action/（`RegzaPresentation` の型としてまとめて作る）、`RegzaAndroid/RegzaPresentation.swift-java.config` | `.build/swift/regzapresentation-java/`（モジュールごとに分けたものは `.build/swift/presentation-java/<モジュール>/`）、`RegzaAndroid/Sources/RegzaPresentationJava/Generated/` |
| 画面のつなぎの生成 | `ScreenGlue` が State/・Action/・ViewModel を読む | 窓口の送る関数（`RegzaAndroidBridge/.../Generated/ScreenActions.swift`）、設定の型の一覧（`RegzaAndroid/*.swift-java.config`）、機能ごとの送り先 `<接頭辞>Send` とプレビューのアプリ `<接頭辞>App`・すべての送り先 `Send`・`SwiftSend`・`SwiftApp`・state の Flow（`.build/swift/screen-glue-kotlin/`）、型ごとのモジュールの一覧（`.build/swift/presentation-types.txt`） |
| 窓口の Java の生成 | `RegzaAndroidBridge/Sources/RegzaAndroidBridge`、`RegzaAndroid/RegzaAndroidBridge.swift-java.config` | `.build/swift/regzabridge-java/`、`RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated/` |
| 偽物の入口の Java の生成（debug だけ） | `RegzaAndroidBridge/Sources/RegzaAndroidFakes`、`RegzaAndroid/RegzaAndroidFakes.swift-java.config` | `.build/swift/regzafakes-java/`、`RegzaAndroid/Sources/RegzaAndroidFakesJava/Generated/` |
| Kotlin へのコールバックの生成 | Kotlin が実装する保存先・通信の型（`build-swift.sh` の `callback_types` で明示する） | `.build/swift/bridge-callbacks/`（途中のもの）、`RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated/JavaCallbacks.swift` |
| native のビルド・梱包 | 接続コード、Swift SDK、NDK | `core/bridge/src/{main,release,debug}/jniLibs/arm64-v8a/` |

- `Android/` の `mise run build-swift` と `mise run build-jvm-host`（どちらも `Android/mise.toml` のタスク）は同じファイルロックを取り、生成とビルドを同時に流さない。`.build/swift-build.lock` は使っている間に消さない
- ログの `[build-swift]` に段階・モジュール・設定が出る。失敗すると、元のエラーに続いて段階・モジュール・設定・行番号・終了コードが出る。
  合成した設定は `.build/swift/configs/` にある
- swift-java のツールは、依存と Swift の版が前と同じならビルドを飛ばす
- 本番の .so（`RegzaAndroid`）と、偽物の入口を足した debug の .so（`RegzaAndroidDebug`）を同じ置き場でビルドし、どちらも `libRegzaAndroid.so` の名前で
  release と debug の置き場に分けて入れる。本番の .so に偽物が入っていないことを毎回確かめる
- APK には、使う .so だけを NEEDED をたどって入れる。FoundationNetworking が残っていれば止まる（通信は OkHttp を使う）
- ICU（`lib_FoundationICU.so`。約 46 MB）は、データを日本語・英語と使う文字コードの分に絞って作り直す（約 12 MB。残すものは `scripts/slim-icu-data.swift`）。
  公開する名前は元の .so と同じにそろえ、ビルドで確かめる。結果が Apple の環境と同じことは端末のテスト `FoundationICUTest` が確かめる。
  比べるときは `./gradlew -PregzaFullICU=true :app:assembleDebug` で元のまま入れられる。ほかの言語の文言を足すときは、`slim-icu-data.swift` の `languages` にも足す
- Linux のホストの JVM では、`HostSwiftRuntime` が専用のスレッドで Swift のライブラリを読み込み、MainActor のキューを JVM の待機から切り離す

### swift-java の制約と回避策

swift-java（`RegzaAndroid/Package.swift` の `revision` で固定したコミット）には次の制約がある。どれも、守れなければビルドかテストで止まるようにしている。

- 型を書いていないプロパティを、警告だけ出して Java にしない。State/ と Action/ の public なプロパティには型を書く
- Foundation の型（`URL`・`Date`・`Data`・`UUID`）を enum の値でしか使っていないと、その型の Java のクラスを作らない。
  enum の値だけで使う型は、共有の UI の型（`RegzaSharedModels`）で一度使う（`URL` は `urlString` で使っている）。
  あとのモジュールの Foundation の型のつなぎは、共有の UI の型のものを使って消すので、ほかのモジュールで初めて使うと消せずに止まる
- Foundation の型の Java のクラスを、使うモジュールごとに作る。どのモジュールも同じ Java のパッケージに出しているので、`build-swift.sh` が
  前のモジュールにもある型のつなぎを消す（パッケージを分けると、`Date` がモジュールごとに別の型になり、渡せなくなる）
- 同じ名前で引数の型だけ違う関数を並べられないので、窓口の送る関数は `send<Action の型>` のように型ごとの名前にする（Kotlin からは送り先を通してどれも `send` で送れる）
- 宣言を Java にできなかったときは、`build-swift.sh` が止まる（`Failed to import`）
- jextract の入力は絶対 file URL にそろえる（相対パスだと Linux で同じ extension を重ねて集める）
- Future のキャンセルが Swift の Task に伝わらない（[swift-java #947](https://github.com/swiftlang/swift-java/issues/947)）ので、Flow の finally から
  `endStateWait` を呼ぶ。直った版に上げるときも、開始前・待機中・state の変化との重なりを端末のテストで確かめてから回避策を外す
- Compose の state の購読（`rememberState`）は `collectAsStateWithLifecycle` を使い、画面が STARTED より下がったら Swift の待機を解き、戻ったら最新の値から受け取り直す
