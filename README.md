# REGZA リモコン

REGZA の HTTP リモコン API（[参考](https://misomayo.info/on/2012/04/10)）を使う iOS アプリ。
録画番組の再生中は、番組名・再生位置を Dynamic Island / ロック画面の Live Activity に表示し、そこから音量・チャンネル・再生操作もできる。

iOS 26 以上が対象。画面はダークモードに固定している（Info.plist の `UIUserInterfaceStyle`）。テレビを見る暗い部屋でまぶしくないようにし、リモコンの配色とほかのタブの明るさをそろえるため。

画面は「リモコン」（テレビを操作するボタン）と、見るための「番組表」「チャンネル」「録画予約」のタブに分けている。テレビで映っているものは、どのタブでもタブバーの上のミニプレーヤー（`tabViewBottomAccessory`）に出し、押すと番組の詳細（録画ならシーク）を開く。色は REGZA の公式サイトで使われている深い緑（`#00442D`）を基調にしている（`AppTheme`。ダークモード固定なので、暗い背景でも見える明るめの `#1D866F` を使う）。ロゴはまねしない。

REGZA だけでもリモコン・Live Activity・Siri・チャンネル一覧と選局・録画予約の一覧・最初から見るが使える。Mirakurun（番組名・番組表・番組表からの予約）と EPGStation（ライブ視聴）は、設定画面の「録画サーバーとの連携」で設定した人だけが使う。番組表のタブは未設定でも消さず（タブを出したり消したりしない HIG に合わせる）、何ができるかと設定のしかたを案内する。連携は、それぞれの設定画面の「連携を解除」でやめられる。アドレスとポートは別々の欄で入れ、ポートが空なら標準のポート（Mirakurun 40772・EPGStation 8888）を使う。保存は `192.168.0.2:40780` のような 1 つの文字列。「探す」と同じサーバーの EPGStation の候補は、標準のポートだけを確かめる。EPGStation は Mirakurun から放送を受け取るので、ライブ視聴は Mirakurun を設定してから設定できるようにし（EPGStation だけでは番組名も出ず、見られない局も一覧に混ざる）、Mirakurun と同じサーバーで EPGStation が動いていれば候補として出す。Mirakurun の連携を解除すると EPGStation の連携も解除する。

## 構成

```
Packages/RegzaCore/           iOS と Android で共有する Swift Package（Foundation のみ）
  RegzaSharedModels           画面に出す UI の型とリモコンのキー（RegzaKey）
  RegzaDomain                 データの型・Repository の約束・UseCase
  RegzaInfrastructure         テレビ・Mirakurun・EPGStation の通信（キーコード / Digest 認証 / HTTP クライアント / status.htm 解析）
  RegzaPresentation           iOS と Android で共有する ViewModel（ViewModels/<画面>/ に ViewModel・State/・Action/）
  RegzaApp                    組み立て（どの Repository を使うかを決めて ViewModel を作る）
  RegzaSample                 テレビにつながない見本の Repository（開発・テスト用）
  RegzaCLI                    ViewModel を動かして確かめる CLI（regza）
iOS/RegzaKit/                 iOS だけで使う Swift Package（マルチモジュール）
  RegzaRemoteViews            SwiftUI の画面（ViewModel の state を見て send で送るだけ）
  RegzaLiveActivity           Live Activity・Dynamic Island の表示と、閉じている間の更新の予約（画面と同じく state を読むだけ）
  RegzaWidgets                Live Activity・ホーム画面のウィジェット・コントロールセンターの見た目（ウィジェット拡張が使う）
  RegzaRemoteIntents          ボタン（Live Activity・ウィジェット・コントロールセンター）からキーを送る App Intent
  RegzaSiriIntents            Siri・ショートカットの App Intent（アプリにだけ登録する）
  RegzaAppContainer           アプリのプロセスに 1 つだけ置くアプリ全体の ViewModel の組み立て（見本のデータも）
  RegzaRemoteUI               アプリの入口（RemoteView。終了時の後片づけなど）
  RegzaDesign                 アプリとウィジェットで共通の色
  RegzaAppleStorage           キーチェーンへの接続情報保存
iOS/RegzaRemote.xcodeproj     アプリ・ウィジェット拡張（モジュールを組み立てるだけの薄い層）
Android/                      Android 版（Kotlin・Jetpack Compose・Navigation 3）
  RegzaAndroidBridge/         Android に見せる Swift の窓口（RegzaAndroidApp）。Mac の swift test で確かめる
  RegzaAndroid/               Android 向けにビルドする Swift のパッケージ（Looper・BoringSSL と、swift-java が作る Java のつなぎ）
  scripts/                    generate-screen-glue.sh（State/・Action/ から窓口のつなぎを作る）
  app/                        Kotlin・Compose のアプリ
  mise.toml                   Swift 6.4.2 のツールチェーンと、Swift の .so と Java のクラスを作る mise run build-swift
```

- Digest 認証は URLSession の認証チャレンジに頼らず `RegzaCore` で自前実装している（Android の FoundationNetworking でも同じコードで動かすため）
- `RegzaCore` は Android（Swift SDK for Android）でもビルドするので、Foundation 以外の Apple のフレームワークを使わない。iOS だけのものは `iOS/RegzaKit`、Android だけのものは `Android/` に置く
- Android からは swift-java で作った Java のクラスを通して `RegzaCore` を使う。画面に出す型とリモコンのキー (`RegzaSharedModels`)、画面の ViewModel の State と Action は、写さずに iOS と同じ型をそのまま使い、Domain の型は Android に見せない（「画面を足す手順」）
- 画面の移り変わり（タブ・タブごとの path）は共有の `AppViewModel` が持ち、iOS は `NavigationStack(path:)`、Android は Navigation 3 の back stack に渡す
- Android の画面のプレビューは、それぞれの画面のファイルの末尾に置く（準備は `SamplePreview.kt`）。見本の返事（`RegzaSample`）で組み立てた共有の ViewModel の state を渡す。state は Swift の値なので、エディタの横のプレビュー（Android Studio が Mac の JVM で描く）では、振る舞いのテストと同じ Mac 向けの Swift のライブラリ（`:behavior-tests:buildJvmHost`。debug のビルドで一緒に作る）を読み込む。「Run Preview」ではエミュレーターでアプリと同じ Android 向けのライブラリを使う。Swift の型は、ライブラリを読み込んだあと（`SamplePreview` の `setUp` と中身）で作る
- OS だけの機能（iOS の Live Activity・ウィジェット・Siri）も、画面と同じく共有の ViewModel の state を読み、Action を送る。共有の部分は「何を出すか」を state に入れるだけで、OS ごとの口（protocol）は持たない
  - iOS は、アプリのプロセスに `AppViewModel` を 1 つだけ置き（`RegzaAppContainer`）、画面・Live Activity・ボタン・Siri・閉じている間の更新が同じものを使う。画面のない入口は、操作を送って終わるまで待ち（`sendAndWait`）、state を見て結果を返す
  - Live Activity は `RemoteViewModel.state` の変わり目を見て表示を更新し、番組の終了時刻が変われば起こしてもらう時刻を予約し直す
  - ボタンの App Intent（`RegzaKeyIntent`）は `LiveActivityIntent` なので、ウィジェットの拡張から押してもアプリのプロセスで動く。Siri の App Intent はふつうの `AppIntent` で、拡張にも登録すると拡張のプロセスで動くことがあるので、アプリにだけ登録する
  - 画面と Live Activity が Domain・通信・組み立てを import していないことは `RegzaKitTests` の `LayerTests` が確かめる
- 接続情報の保存は `RegzaConnectionStore` を OS ごとに実装する。iOS はキーチェーン（`RegzaAppleStorage`）、Android は Kotlin の `AndroidStorage`（SharedPreferences。パスワードは Android Keystore の鍵で暗号化する）を、Swift の保存先 `RegzaAndroidStorage` として差し込む
- `RegzaCore` の通信は `HTTPTransport` を通す。iOS は URLSession、Android は `SocketTransport`（自前の HTTP/1.1。Android の URLSession は返事を待つ間 CPU を使い続けるため）。Android の HTTPS は Swift SDK for Android に入っている BoringSSL で暗号化し、証明書は Android が信頼している認証局で確かめる（テレビの 4430 番は自己署名なので、iOS と同じく確かめない）

## 開発

```sh
cd Packages/RegzaCore && swift test       # 共有部分のテスト
cd Android/RegzaAndroidBridge && swift test  # Android の窓口のテスト (Mac で動く)
open iOS/RegzaRemote.xcodeproj            # 実機へ入れるときは下の Local.xcconfig を作る

cd Android                                # Android 版（Android Studio はなくてもよい）
mise install                              # Swift のツールチェーン・JDK・Android CLI
mise run setup-android-sdk                # 初回だけ。Android SDK のライセンスを確かめて同意する（Android Studio で SDK を入れていれば要らない）
mise run install-android-swift-sdk        # 初回だけ。Swift SDK for Android（platform・build-tools・NDK は Gradle が入れる）
./gradlew :app:assembleDebug              # Swift の .so と Java のクラスも先に作る (buildSwift が mise run build-swift を呼ぶ)

cd BehaviorTests && mise run test         # 振る舞いのテスト (両方の相手をビルドして、同じテストを iOS 側と Android 側で流す)
```

### 振る舞いのテスト

Shopify の [Reflex](https://shopify.engineering/reflex) と同じ作りで、画面を描かずに ViewModel の state と操作を確かめる。テストは `BehaviorTests/`（Bun・TypeScript）に 1 回だけ書き、iOS 側と Android 側の 2 つの相手に同じテストを流す。片方だけ通る状態は失敗になる。テストは相手がどちらかを知らず、CLI と同じ約束事（`tree`・`ls`・`do`・`wait` の 1 行ずつの命令と JSON）だけを使う。

- iOS 側の相手は `regza`（iOS と同じ共有の組み立てを Mac で動かす）
- Android 側の相手は `regza-android`（`Android/behavior-tests`。Mac の JVM）。命令の読み方と返す JSON は `regza` と同じもの（`IntrospectionSession`）を使い、操作を送るところと state を受け取るところだけを、アプリと同じ道（Kotlin の `send` と `xxxStates` → swift-java のつなぎ → 窓口）で行う。窓口とつなぎは macOS 向けの .dylib（`RegzaJVMHost`）にして読み込む。エミュレーターは使わない
- 外からの入力は見本の返事（`RegzaSample` の `SampleTransport`）で渡すので、テレビにも録画サーバーにもつながない
- テストは `sdk/app.ts` の `describeOnBothPlatforms` で書き、`do`（操作を送り、state が期待どおりになるまで待つ）と `precondition`（state が期待どおりになるまで待つ）で確かめる
- 「テレビにつながらない」「チャンネル一覧が空」のような場面は、`describeOnBothPlatforms` に fixture（`SampleFixture`。宛先ごとの返事の差し替えと、つながらないアドレス）を渡して作る。両方の相手に、起動するときに `--fixture <JSON のファイル>` で渡る
- Swift 6 からは、Android の Foundation も iOS と同じ swift-foundation（JSON・Date・Calendar・URL・書式など）を土台にしているので、Mac で動かしても大半は Android と同じものを通る。確かめないのは Android の土台（ART と JNI・Bionic・Looper で動かす MainActor・APK の中の .so の読み込み）と、swift-corelibs-foundation に残る部分（RunLoop・Thread など）で、これらはエミュレーターや実機でアプリを動かして確かめる

バンドル ID（`com.example.RegzaRemote`、ウィジェットは `com.example.RegzaRemote.Widget`）と署名のチームは `iOS/Config/Signing.xcconfig` にまとめている。自分でビルドして実機に入れるときは、このファイルは変えずに、同じフォルダに `Local.xcconfig` を作って自分の値で上書きする（Git には入れない）。

```
// iOS/Config/Local.xcconfig
BUNDLE_ID_PREFIX = com.yourname
DEVELOPMENT_TEAM = ABCDE12345
```

テレビや Mirakurun につながずに画面を確かめるときは、Debug ビルドを起動引数 `-SampleData YES` で起動すると見本データ（架空のチャンネルと番組）を表示する。`-SampleKind recorded` で録画再生中、`-InitialTab guide` / `channels` / `reservations` で最初に開くタブを選べる。`-InitialTab guide -SampleDetail YES` で放送中の番組の詳細を開く。`-SampleNoGuide YES` で Mirakurun が未設定のとき、`-ShowSettings YES` で設定画面を開いた状態を確かめられる。`-InitialTab guide -SampleSearch <言葉>` で番組の検索を開く。`-LiveHost <EPGStation のアドレス> -LiveChannel <チャンネルの ID>` で、すぐライブ視聴の再生画面を開く（実際に配信を頼むので、確かめたら EPGStation で配信を止める）。

```sh
xcrun simctl launch booted com.example.RegzaRemote -SampleData YES -InitialTab guide
```

画面の余白・ボタンの高さ・色は `Design`（`RemoteControls.swift`）と `AppTheme` にまとめている。余白は 16 / 12 / 24、ボタンの高さは 56 / 48 / 40 の 3 段階だけを使い、色は選択中・進行中（緑）と電源・録画（赤）だけに使う。リモコンのタブは、テレビ付属のリモコンの写真から測った色に合わせ、明るいグレーの本体にグレーのボタンと黒い文字、十字キーのあたりだけ黒い帯に黒いボタンと白い文字、銀色の決定、赤い電源ボタンの配色（`RemoteBody`・`RemoteKeyTone`）にしている。

## 画面を足す手順

画面の状態と操作は、iOS と Android で同じ ViewModel（`RegzaPresentation`）が持つ。ViewModel は Elm 風で、画面に出すものを `state`、画面からの操作を `send(Action)` で受ける。Android は ViewModel の State と Action の型を swift-java でそのまま Java のクラスにして使い、間の窓口（`Android/RegzaAndroidBridge`）は、`scripts/generate-screen-glue.sh` が State/ と Action/ のフォルダから作る。画面を足すときに窓口を手で書くことはない。

### 1. 共有の ViewModel を作る

`Packages/RegzaCore/Sources/RegzaPresentation/ViewModels/<画面>/` に置く。例はチャンネル一覧（`ChannelList/`）。

```
ViewModels/ChannelList/
├── ChannelListViewModel.swift      ViewModel
├── State/ChannelListState.swift    画面に出すもの
└── Action/ChannelListAction.swift  画面からの操作
```

- ViewModel は `@MainActor @Observable public final class` にし、`public typealias State = ChannelListState` と `public typealias Action = ChannelListAction` を書く。ツールはこの 2 行で、どの ViewModel にどの型を送るかを決める
- State/ と Action/ の型は 1 つのファイルに 1 つ置き、名前は画面の名前で始める（`LivePlayerPhase` のように State の中で使う enum も State/ に置く）。ここに置いた型だけが Java のクラスになる
- State と Action には UI の型（`RegzaSharedModels`）だけを使い、Domain の型は使わない（Android に見せないため。ViewModel の Domain を使う init やプロパティは `package` にする）
- 表示の判断（ボタンを出すか、押せるか、保存できるかなど）は State に入れ、画面に式を書かない。画面に置いた判断はテストでも CLI（`regza`）でも確かめられず、iOS と Android にそれぞれ書くことになる
- 1 つの画面に Action は 1 つにする。部品に分けた ViewModel（設定のテレビの登録など）の操作は、親の Action の case に入れて送る（`SettingsAction.tv(TVSetupAction)`）。部品の ViewModel には `typealias Action` を書かない（書くと Android から直接送れてしまう）
- CLI と振る舞いのテストから動かせるよう `IntrospectableActions` にし、名前と引数の操作を Action にする `action(_:_:)` を書く（CLI も Android 側の相手もこれを使うので、置き換えは 1 か所だけ）。state を要約したり伏せたりするときは `introspectionJSON(of:)` に書く。Action のどの case も `action(_:_:)` で作れるようにする（アプリの画面から送れる操作は、どれも約束事からも送れる。`ContractCoverageTests` が漏れを確かめる）
- テストを `Tests/RegzaCoreTests/RegzaPresentation/ViewModels/` に足す

### 2. AppViewModel から開けるようにする

- タブの最初の画面なら `AppViewModel` に持たせて `openViewModels` に並べる
- タブの中で開く画面なら `AppRoute` に case を足し、`AppViewModel.viewModel(for:)` でその ViewModel を返す（`id` も足す）。開くのは `AppAction.push(route)`、戻るのは `pop`

### 3. iOS の画面を作る

`iOS/RegzaKit/Sources/RegzaRemoteViews/` に置き、`viewModel.state` を見て `viewModel.send(...)` で送る。`RegzaDomain` は import しない（`LayerTests` が確かめる）。

### 4. Android の画面を作る

```sh
cd Android
scripts/generate-screen-glue.sh     # ./gradlew のビルドでも毎回実行される
```

ツールが作るもの（作ったものはコミットする。古いままだと窓口のテスト `screenGlueIsUpToDate` が失敗する）:

- 窓口の送る関数（`sendChannelListAction`）と state を返す関数（`channelListState(route:)`・`nextChannelListState(route:after:waitID:)`）: `RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift`。Kotlin の Flow が終わると `endStateWait` で Swift 側の待機も終える
- swift-java の設定の型の一覧（`RegzaAndroid/*.swift-java.config` の `importedModuleStubs`）
- Kotlin の送り先 `Send`（`send(ChannelListAction.tune(code))` のように、どの Action も `send` で送れる）と、state の `Flow`（`app.channelListStates(route)`）: ビルドのたびに `.build/swift/screen-glue-kotlin/` に作る

Kotlin の画面は、自分の ViewModel の state を受け取って描き、操作を `send` で送る。タブの最初の画面なら `MainActivity.kt` の `TabRoot`、タブの中で開く画面なら `RouteScreen` に足す。

```kotlin
rememberState(key) { app.programListStates(route) }?.let { ProgramListScreen(it, back, send) }
```

### 5. 確かめる

```sh
cd Packages/RegzaCore && swift test
cd Android/RegzaAndroidBridge && swift test
cd Android && ./gradlew :app:assembleDebug
cd BehaviorTests && mise run test
```

画面を足したら、`BehaviorTests/tests/` にもその画面の振る舞いのテストを足す（操作を送り、state が期待どおりになるまで待つ）。

### swift-java の制約と回避策

swift-java（301e3da）には次の制約がある。どれも、守れなければビルドかテストで止まるようにしている。

- 型を書いていないプロパティ（`public var count = 0`）を、警告だけ出して Java にしない。State/ と Action/ の public なプロパティには型を書く（`public var count: Int = 0`）。書いていなければ `generate-screen-glue.sh` が止まる
- Foundation の型（`URL`・`Date`・`Data`・`UUID`）を enum の値（`case ready(url: URL)`）でしか使っていないと、その型の Java のクラスを作らず、javac が失敗する。`URL` は窓口の `regzaURLString` が使うので作られる。ほかの型を enum の値だけで使うときは、窓口などで一度使う
- Foundation の型の Java のクラスを、使うモジュールごとに作る。3 つのモジュール（`RegzaSharedModels`・`RegzaPresentation`・`RegzaAndroidBridge`）は同じ Java のパッケージに出しているので、そのままでは同じ名前の JNI の関数がぶつかってリンクできない。`mise run build-swift` が、前のモジュールにもある型のつなぎを消す（消せない混ざり方なら止まる）。モジュールごとにパッケージを分けると、ぶつからない代わりに `Date` がモジュールごとに別の型になり、モジュールをまたいで渡せなくなる
- 同じ名前で引数の型だけ違う関数を並べられない。窓口の送る関数を `sendChannelListAction` のように型ごとの名前にしているのはこのため（Kotlin からは `Send` を通してどれも `send` で送れる）
- swift-java が何か宣言を Java にできなかったときは、`mise run build-swift` が止まる（`Failed to import`）

## テレビ側の準備

- 設定画面の「テレビを探す」で同じネットワークの REGZA を検出する
  - 自分の /24 のアドレスすべてに `GET /public/feature`（認証不要）を並列に問い合わせ、`device_type` が `DTV` のものを候補にする。応答の `ipc_feature` に `PIN_Auth` があれば PIN 登録に対応している
  - SSDP はマルチキャストの entitlement が必要なので使っていない。初回は iOS のローカルネットワーク許可が必要
- 見つからないときは IP アドレスを手入力する
- 使用中にテレビへつながらなくなったら（通信エラーのとき）、同じ方法で探し直し、保存済みの資格情報で認証が通ったテレビのアドレスに切り替える（DHCP でアドレスが変わった場合など）。電源が切れているだけのこともあるので、探し直しは 3 分に 1 回まで
- テレビを選ぶか IP アドレスを入力し、「テレビに PIN を表示」→ テレビに出た PIN を入力して登録する（レグザAppsコネクト v2 の `request_connection` / `confirm_connection`）
  - パスワードは PIN から作った鍵（PBKDF2-HMAC-SHA1, 1331 回）の AES-128-CBC で暗号化されて届く。Android でも動くよう SHA-1 / AES は `RegzaCore` で自前実装している
  - ユーザー ID はアプリ用に MAC アドレス形式のランダムな値を 1 つ作り、キーチェーンに保存して使い回す（iOS は本物の MAC アドレスを取得できない）。同じ ID で登録し直すとテレビ側で上書きされ、前のパスワードは無効になる。キーチェーンはアプリを削除しても残るので、入れ直しても登録は増えない
  - 手入力されたユーザー名は他のツールと共有しているかもしれないので、PIN 登録には使わない
  - 別のユーザー ID の登録は共存する（アプリと別のツールを別々の ID で登録し、両方で操作できることを実機で確認）。登録できる件数の上限と、テレビ側で登録を削除する方法は不明（取扱説明書に記載がない）
- PIN 登録に対応していない機種は、テレビの外部連携設定で決めたユーザー名・パスワードを手入力する
- 電源 ON をスマホから行うには、待機時の通信（クイック起動など）を有効にする

## 視聴状況の取得

- レグザAppsコネクト v2 API の `GET /v2/remote/play/status` を優先して使う（HTTP 80番で動作）
  - 放送: チャンネル名、番組の開始時刻・長さ、次の番組の開始時刻
  - 録画再生: 番組名、番組説明、再生位置、再生/一時停止
  - 外部入力 (HDMI)・待機中も判別できる
- v2 API が無い機種（404 など）では旧 API の `status.htm` に切り替える（録画再生中の情報のみ）
- 対応 API の一覧は `GET /v2/remote/support` で確認できる（HTTP 80 番では暗号化されて返る。HTTPS 4430 番なら JSON のまま読める）

## チャンネル一覧

- `GET /v2/remote/settings/channel_list` でテレビに登録されているチャンネルを取得し、地デジ・BS・CS ごとに並べる（種類は `ex_channel_number` の `DUV` / `DBS` / `DCS` で見分ける）
- 押すと `POST /v2/remote/status/channel`（フォーム `channel` にチャンネル一覧の `channel` の値）で直接選局する。成功すると `{"status":0}`、存在しないチャンネルは `{"status":1}`
- いま映っているチャンネルは `play/status` の `epg_info_current.channel` と照らし合わせて印を付ける

## 番組表（Mirakurun）

テレビの番組表 API は番組名を返さないので、Mirakurun（録画サーバー）が設定されていれば、そこから番組名と番組表を読む。設定画面で同じ /24 のポート 40772 に `GET /api/version` を問い合わせて探せる。認証は不要。

- テレビと Mirakurun は放送波の ID をそのまま使っているので、変換するだけで照らし合わせられる
  - チャンネル: テレビの `JP-G` + network_id + service_id（16 進 4 桁ずつ）。例: `JP-G7fe00400`
  - 番組: テレビの `epg_content_id`（`JP-0000` + network_id + service_id + event_id）→ Mirakurun の番組 ID `network_id × 10^10 + service_id × 10^5 + event_id`
- 放送中の番組名が空のときは `GET /api/programs/:id` で補い、アプリと Live Activity に出す。同じ番組は問い合わせ直さない
- `GET /api/programs`（全チャンネル分で数 MB）は 30 分に 1 回まで読み、チャンネル一覧の各局の今の番組名と、番組表の画面に使う
  - 番組表の画面は横に局、縦に時刻を並べ、ジャンルごとに色を分ける。日付のボタン（今日・明日・6(金) …。Mirakurun が番組表を持っている日まで）で日を選べる。今日は今の正時から 24 時間、ほかの日はその日の朝 4 時から次の日の朝 4 時まで（日本の番組表と同じく、深夜番組は前の日の続きとして 24〜27 時と書く）。同じリモコン番号のサブチャンネルは代表の局だけ出す
  - チャンネル一覧のカレンダーのボタンからは、その局だけの番組表（`?networkId=&serviceId=`、8 日分ほど）を開ける
  - 番組表のナビゲーションバーの虫眼鏡から開く検索（番組表を広く使うため、検索欄は番組表の上に置かず別の画面にする）は、読み込んだ全部の番組（1 週間分）の番組名・説明・番組内容・出演者から探す。全角半角・ひらがなカタカナ・大文字小文字は区別しない。番組名に入っていないときは「〇〇 が出演」「説明に「〇〇」」と見つかったわけを添える。打った言葉のうち、日付（今日・明日・土曜・11/7 など）・時間帯（朝・夜・深夜・ゴールデン・21時から など）・ジャンル名は条件として読み（「明日の夜のサッカー」→ 明日・18〜28 時・「サッカー」）、× で外せる。言葉の途中は読まない（「朝ドラ」「大河ドラマ」はそのまま探す）。「夜のニュース」のような番組名を探すときは「そのまま探す」で条件を読まずに探せる
  - 端末の AI（FoundationModels）で言葉を広げる（「SMAP」→ メンバーの名前）ことも試したが、端末のモデルは知識が少なく（別のグループのメンバーを答える、存在しない名前を作る）、1 回に 10 秒以上かかったため使っていない。クラウドのモデル（Private Cloud Compute）は iOS 27 以降で、Apple に申請する権限が要る
- Mirakurun が受信していない放送（CS など）は番組名が出ない

## ライブ視聴（EPGStation）

EPGStation が設定されていれば、放送中の番組をアプリで見られる（番組の詳細と視聴中の画面の「アプリで見る」）。家の Wi-Fi の中だけで使う。

再生画面は縦向きでは映像の下に今の番組の情報（Mirakurun の番組表から。30 秒ごとに更新）と局の一覧を出し、局を押すと前の配信を止めてその局の配信を頼み直す。局の一覧は Mirakurun が受信している局（＝ EPGStation で見られる局）の代表チャンネルだけで、地デジ/BS/CS の選択は番組表・チャンネルのタブと共有する。横向きでは映像だけを出す。映像の部分は iOS 標準のプレーヤーなので、全画面・ピクチャインピクチャ・AirPlay のボタンはそのまま使える。

- `GET /api/streams/live/:channelId/hls?mode=0` で配信を頼み、`/streamfiles/stream{番号}.m3u8` に映像の部分（.ts）が載ったら iOS 標準のプレーヤー（AVPlayerViewController。ピクチャインピクチャ・AirPlay 対応）で再生する。映像は H.264、音声は AAC で届く
- チャンネル ID は Mirakurun のサービス ID と同じ（`network_id × 100000 + service_id`）
- 見ている間は `PUT /api/streams/:id/keep` を 10 秒ごとに送り、閉じたら `DELETE /api/streams/:id` で止めてチューナーを空ける
- EPGStation は keep が途切れても配信を自動では止めない（160 秒待っても残った）。そのため、アプリが頼んだ配信の番号を覚えておき、強制終了などで止められなかったものは、次にアプリを開いたとき・次に配信を頼むときに止める。終了するときも止めてみる
- 配信が始まらなかったときは、利用者が選んだ場合だけ、準備できないまま残っている配信（ほかの端末のものも含む）を止めてからもう一度頼む
- 頼んでから再生できるまで 20 秒ほどかかる。同時に変換できる数に上限がある構成では、ほかで見ている配信があると始まらないことがある
- 画質は EPGStation の設定の最初のもの（mode 0）だけを使う
- EPGStation で録画する機能は入れていない（録画先がテレビと EPGStation の 2 つになり、予約の画面が分かりにくくなるため）

## 録画

- 録画予約の追加: 番組表の番組の詳細から `POST /v2/remote/pvr/reserves/new`（フォーム `channel` `epg_content_id` `start_time` `duration`）で 1 回だけ予約する
  - HTTP（80 番）では内容によらず `{"status":2}` になり、HTTPS（4430 番）でだけ受け付ける。テレビの証明書は自己署名なので、4430 番への接続に限って受け入れている
  - `epg_content_id` は Mirakurun の network_id / service_id / event_id から組み立てる
- 連ドラ予約: 同じ API に `series_rec=true` だけを足して送る。繰り返し（毎週・月〜金など）とキーワードはテレビが番組から決める（`repeat_series` や `keyword_series` を自分で入れると `{"status":2}` になった）
- タイムシフトマシンの再生（`POST /v2/remote/timeshift/list/:channel_code`）と番組一覧（GET）は、値の形式が分からず使えていない（`{"status":1}` か `2` が返る）
- 最初から見る: リモコンの「始めにジャンプ」キーを送る。タイムシフトマシンで録画していない番組で押すとテレビにエラーが出るので、`GET /v2/remote/settings/timeshift` の対象の局（`target_channel`）と録画する時間帯（`active_time_list`。曜日ごとの 16 進の値の下位 24 ビットが 0〜23 時。例: 平日 19 時〜翌 1 時なら `00f80001`）から、番組の始まりから今までずっと録画しているときだけボタンを出す
- 録画予約の取り消し: `DELETE /v2/remote/pvr/reserves/list/:rsv_id`（HTTP で動く）。一覧の行を左にスワイプする
- 録画予約の一覧: `GET /v2/remote/pvr/reserves/list`。連ドラ予約は次の回が番組表に載ると `start_time` と `title` がその回に更新され、それまでは最後に録画した回のまま残るので、「予定」と「次の回を待っている」に分けて出す
- 録画番組の一覧は表示しない（リモコンの「録画リスト」キーでテレビの一覧を開く）
  - v2 API には一覧がない。テレビの DLNA サーバー（ポート 20003 の `ContentDirectory`）からは一覧を取れるが、映像は DTCP-IP で保護されているのでアプリでは再生できない
  - テレビで番組を指定して再生する `POST /v2/remote/pvr/play/list/:rec_storage_id/:rec_content_id` はあるが、DLNA の番組 ID（独自の `X_Toshiba_REGZA_Browse` も含む）から `rec_content_id` を求められなかった
- 番組表 `GET /v2/remote/epg/:channel_code?time=<Unix 秒>` は番組名・説明が空で返るため使っていない

## Siri・ショートカット

App Intents で次の操作を出している（`RemoteIntents.swift`。言い方の登録はアプリのターゲットの `RegzaRemoteShortcuts`）。

- チャンネルを切り替える（`TuneChannelIntent`）: テレビのチャンネル一覧から局を選ぶ。全角・半角や「・」の違いを無視して局名で探すので、「NHK」でも「ＮＨＫ総合１・東京」に合う
- テレビを操作する（`RemoteCommandIntent`）: 電源・音量・消音・チャンネルの上下・入力切替・再生・一時停止・停止・30 秒送り・10 秒戻し・録画リストを、回数を指定して押す
- Siri では「REGZAリモコンで NHK総合にして」「REGZAリモコンで消音」「REGZAリモコンでテレビをつけて」のように呼ぶ。チャンネル名の候補はアプリを開いたときにテレビの一覧で更新する

## ホーム画面のウィジェット

ホーム画面に置くリモコンのウィジェット（`RemoteWidget.swift`。小は置けるボタンが少なく、同じ操作はコントロールセンターのボタンで足りるので出さない。中: 電源・入力切替・消音・チャンネルの上下・音量の上下、大: 電源・入力切替・消音・地デジ/BS/CS・数字 1〜12・黒い帯に音量とチャンネルの上下・再生の段（10 秒戻し・再生・一時停止・30 秒送り）で、実物のリモコンに近い並び。数字を主役にするため、数字以外の段は低くそろえる。再生と一時停止は、ウィジェットからは今の状態が分からないので別々のボタン）。番組名などは出さず、ボタンだけを並べる（ウィジェットはすぐには更新されないので、今の番組は Live Activity に任せる）。ボタンはコントロールセンターのボタンと同じく `RegzaKeyIntent` でキーを送る。配色はリモコンのタブと同じ明るいグレーの本体・グレーのボタン・赤い電源。

## コントロールセンターのボタン

ウィジェット拡張に、コントロールセンター・ロック画面・アクションボタンに置けるボタン（ControlWidget）を入れている（`ControlCenterControls.swift`）。電源・消音・音量の上下・チャンネルの上下の 6 つで、押すと `RegzaKeyIntent` でキーを送る。`RegzaKeyIntent` は LiveActivityIntent なので、ウィジェット拡張ではなくアプリのプロセスで動き、キーチェーンのテレビの登録情報をそのまま使える。

## 制限

- 録画の再生を始めるなど、テレビの映像が切り替わっている最中に `play/status` を問い合わせると、テレビが再起動する機種がある（決定キーの 0.4 秒後の問い合わせで再起動し、決定キーだけでは起きないことを実機で確認）。決定・再生・停止・戻る・終了などのキーを送った後と、選局した後は 6 秒間問い合わせない（選局の直後に問い合わせると status 1 が返ることも実機で確認）
  - テレビ本体のリモコンで切り替えられたときにも重ならないよう、ふだんの 2 秒ごとの確認は旧 API（`status.htm`）で行う。旧 API は切り替えの最中に 0.2 秒おきに問い合わせても再起動しないことを実機で確認した。旧 API の値（再生状態・チャンネル・番組）が変わったら切り替え中とみなして 6 秒待ち、`play/status` は落ち着いているときに 15 秒に 1 回と、自分でキーを送った後だけにする。その間の再生位置は旧 API の値や経過時間で進める
  - 2 秒ごとの確認・キーを送った後の取り直し・Live Activity の更新が重なると、ほかの確認が見つけた切り替わりを見落として `play/status` を問い合わせ、テレビが応答しなくなることを実機で確認した。確認は 1 本ずつ行い、`play/status` の直前にも待ち時間の最中でないかを確かめる
  - テレビ本体のリモコンで放送のチャンネルを変えたことは、旧 API では分からないので、反映まで最大 15 秒ほどかかる
- 切り替え中は `play/status` が一時的に 404 を返す。一度でも v2 API で取れたテレビでは、404 が返っても旧 API（`status.htm`）に切り替えない
- 機種によっては v2 API が放送中の番組名・番組説明を空文字で返す（`/v2/remote/epg/:channel_code` も同様）。Mirakurun がなければ、チャンネル名と放送時間に、`play/status` のジャンル（`genre` の 4 桁の 16 進の 3 桁目が ARIB の大分類。`00a8` なら趣味・教育）を添えて表示する
- Live Activity は、アプリを開いている間は 2 秒ごとに更新される。閉じている間は次のときに更新される
  - Live Activity のボタンを押したとき
  - iOS がアプリを起こしたとき（BGAppRefreshTask。放送中は番組の終了時刻の後、それ以外は 15 分後以降で予約するが、実際にいつ起こされるかはシステム次第で、起こされないこともある）
  - 放送中は番組の終了時刻を staleDate にしているので、アプリが起こされなくても、その時刻に次の番組（`epg_info_next` の開始時刻・長さと、Mirakurun があれば番組名）の表示へ切り替わる。同じチャンネルを見続けている前提の予想なので、テレビ本体のリモコンでチャンネルを変えていたら、次にアプリが状態を取るまで違う番組が出る
- テレビ本体のリモコンでチャンネルを変えたことは、アプリを開くか iOS がアプリを起こすまで反映されない
- 確実に更新するには、家のサーバーからテレビの状態を見て ActivityKit のプッシュ通知を送る仕組みが必要（未実装）
