# REGZA リモコン

両 OS 共通の余白・サイズ・ブランド色・リモコン配色は [デザイントークン](Design/README.md) の JSON から Swift・Kotlin へ生成する。

画面の固定文言は [共通の文字列](Localization/README.md) のString Catalogで管理し、Android XMLと両OSの参照コードを生成する。

REGZA の HTTP リモコン API（[参考](https://misomayo.info/on/2012/04/10)）を使う iOS アプリ。
録画番組の再生中は、番組名・再生位置を Dynamic Island / ロック画面の Live Activity に表示し、そこから音量・チャンネル・再生操作もできる。

iOS 26 以上が対象。iOS・Androidとも設定の「外観」から「システムに合わせる」「ライト」「ダーク」を選べる。初期値はOSへの追従で、選択は即座に反映・端末へ保存する（テレビ接続設定の保存・キャンセルとは独立）。共通のカラートークンから、iOSのColor AssetとAndroidの標準色リソースを生成する。リモコン本体は実物を模した配色を両外観で共通にする。

画面は「リモコン」（テレビを操作するボタン）と、見るための「番組表」「チャンネル」「録画予約」のタブに分けている。テレビで映っているものは、どのタブでもタブバーの上のミニプレーヤー（`tabViewBottomAccessory`）に出し、押すと番組の詳細（録画ならシーク）を開く。色は REGZA の公式サイトで使われている深い緑（`#00442D`）を基調にしている（`AppTheme`。ライトでは `#006B4F`、ダークでは暗い背景でも見える明るめの `#1D866F` を使う）。ロゴはまねしない。

REGZA だけでもリモコン・Live Activity・Siri・チャンネル一覧と選局・録画予約の一覧・最初から見るが使える。Mirakurun（番組名・番組表・番組表からの予約）と EPGStation（ライブ視聴）は、設定画面の「録画サーバーとの連携」で設定した人だけが使う。番組表のタブは未設定でも消さず（タブを出したり消したりしない HIG に合わせる）、何ができるかと設定のしかたを案内する。連携は、それぞれの設定画面の「連携を解除」でやめられる。アドレスとポートは別々の欄で入れ、ポートが空なら標準のポート（Mirakurun 40772・EPGStation 8888）を使う。保存は `192.168.0.2:40780` のような 1 つの文字列。「探す」と同じサーバーの EPGStation の候補は、標準のポートだけを確かめる。EPGStation は Mirakurun から放送を受け取るので、ライブ視聴は Mirakurun を設定してから設定できるようにし（EPGStation だけでは番組名も出ず、見られない局も一覧に混ざる）、Mirakurun と同じサーバーで EPGStation が動いていれば候補として出す。Mirakurun の連携を解除すると EPGStation の連携も解除する。

## 構成

```
toolchains.toml              Swift・Android SDK・Xcode の共通バージョン設定
Packages/RegzaCore/           iOS と Android で共有する Swift Package（REGZA の OpenAPI 生成クライアントも共有）
  RegzaSharedModels           画面に出す UI の型とリモコンのキー（RegzaKey）
  RegzaDomain                 Data・Repository の約束・UseCase・SharedModel への変換
  RegzaInfrastructure         テレビ・Mirakurun・EPGStation の通信（キーコード / Digest 認証 / HTTP クライアント / status.htm 解析）
  RegzaPresentation           iOS と Android で共有する ViewModel（ViewModels/<画面>/ に ViewModel・State/・Action/）
  RegzaApp                    組み立て（どの Repository を使うかを決めて ViewModel を作る）
  RegzaSample                 テレビにつながない見本の Repository（開発・テスト用）
  RegzaCLI                    ViewModel を動かして確かめる CLI（regza）
iOS/RegzaKit/                 iOS だけで使う Swift Package（7 モジュール）
  AppServices/                iOS の DI・依存の保持・終了時の配信停止（Storage/ に保存実装、Preview/ に見本の組み立て）
  UI/                         画面（Screens/）・補助 View（Components/）・画面遷移（Navigation/）
  Design/                     アプリとウィジェットで共通の色
  LiveActivity/               Live Activity の状態・更新・バックグラウンド更新の予約
  SystemActions/              Live Activity・ウィジェット・コントロールセンターのボタンからの操作
  Shortcuts/                  Siri・ショートカット（アプリにだけ登録する）
  Widgets/                    Live Activity・ホーム画面・コントロールセンターの表示
iOS/RegzaRemote/              アプリの起動・RootView（依存を画面へ渡す、終了通知を AppServices へ渡す）
iOS/RegzaRemote.xcodeproj     アプリ・ウィジェット拡張（モジュールを組み立てるだけの薄い層）
Android/                      Android 版（Kotlin・Jetpack Compose・Navigation 3）
  RegzaAndroidBridge/         Android に見せる Swift の窓口（RegzaAndroidApp）。macOS・Linux の swift test で確かめる
  RegzaAndroid/               Android 向けにビルドする Swift のパッケージ（Looper と、swift-java が作る Java のつなぎ）
  ScreenGlue/                 窓口のつなぎを作る道具（screen-glue。State/・Action/ の型を swift-syntax で読む。ホストで動かし、アプリには入らない）
  scripts/                    build-swift.sh（Swift の .so と Java のクラスを作る）・swift-toolchain.sh（mise の Swift を選ぶ）
  app/                        Kotlin・Compose のアプリ
  mise.toml                   共通設定の Swift ツールチェーンと、Swift の .so と Java のクラスを作る mise run build-swift（中身は scripts/build-swift.sh）
```

- Swift のコードの書き方は swift-format（Swift のツールチェーンに入っている Apple の道具）でそろえる。設定は `.swift-format`（行の長さ 140・インデントは空白 4 つ・`#if` の中は下げない、ほかは既定の決まり）。Kotlin は ktlint でそろえる。設定は `.editorconfig`（Android Studio の書き方・行の長さ 140・`@Composable` の関数は大文字で始めてよい）で、Android Studio もこの設定で整形する。複数行に並べたものは、Kotlin では宣言でも呼び出しでも末尾にコンマを付け、Swift では配列や辞書に付ける（関数の引数は書いたとおりに残す。swift-format の「必ず付ける」は閉じかっこの前に `, )` を残す不具合があるため使わない）。`mise run lint` で両方を確かめ、`mise run format` で両方を直す。道具が作るファイル（`Generated/`・`.build/`）は対象にしない。ルートの `mise.toml` には共通タスクと Bun・ktlint の設定を置き、Swift の版は `toolchains.toml` を参照する。ルートでは Swift のコンパイラを切り替えない（初めてのときは `mise trust` と `mise install` が要る）
- Digest 認証は URLSession の認証チャレンジに頼らず `RegzaCore` で自前実装し、URLSession と OkHttp で共有する。
- `RegzaCore` は Android（Swift SDK for Android）でもビルドするので、Foundation 以外の Apple のフレームワークを使わない。iOS だけのものは `iOS/RegzaKit`、Android だけのものは `Android/` に置く
- Android からは swift-java で作った Java のクラスを通して `RegzaCore` を使う。画面に出す型とリモコンのキー (`RegzaSharedModels`)、画面の ViewModel の State と Action は、写さずに iOS と同じ型をそのまま使い、Domain の型は Android に見せない（「画面を足す手順」）
- 画面の移り変わり（タブ・タブごとの path）は共有の `AppViewModel` が持ち、iOS は `NavigationStack(path:)`、Android は Navigation 3 の back stack に渡す
- Android の画面のプレビューは、それぞれの画面のファイルの末尾に置く（準備は `SamplePreview.kt`）。見本の返事（`RegzaSample`）で組み立てた共有の ViewModel の state を渡す。エディタの横のプレビューはホストの JVM で描くため、先に `mise run prepare-android-preview` でホスト向けライブラリを作る（macOS は .dylib、Linux は .so）。APK のビルドではホスト向けライブラリを作らない。「Run Preview」ではエミュレーターでアプリと同じ Android 向けのライブラリを使う。Swift の型は、ライブラリを読み込んだあと（`SamplePreview` の `setUp` と中身）で作る
- OS だけの機能（iOS の Live Activity・ウィジェット・Siri）も、画面と同じく共有の ViewModel の state を読み、Action を送る。共有の部分は「何を出すか」を state に入れるだけで、OS ごとの口（protocol）は持たない
  - iOS は、アプリのプロセスに `AppViewModel` を 1 つだけ置き（`AppContainer`）、画面・Live Activity・ボタン・Siri・閉じている間の更新が同じものを使う。画面のない入口は、操作を送って終わるまで待ち（`sendAndWait`）、state を見て結果を返す
  - Live Activity は `RemoteViewModel.state` の変わり目を見て表示を更新し、番組の終了時刻が変われば起こしてもらう時刻を予約し直す
  - ボタンの App Intent（`RegzaKeyIntent`）は `LiveActivityIntent` なので、ウィジェットの拡張から押してもアプリのプロセスで動く。Siri の App Intent はふつうの `AppIntent` で、拡張にも登録すると拡張のプロセスで動くことがあるので、アプリにだけ登録する
  - 画面と Live Activity が Domain・通信・組み立てを import していないことは `RegzaKitTests` の `LayerTests` が確かめる
- 依存オブジェクトの引数・プロパティ・組み立て時の変数は、`remoteViewModel`・`guideUseCase`・`guideRepository`・`regzaAPIClient`・`preferencesManager` のように役割を名前に含める。取得した値は `programs`・`channels` など、内容を表す名前にする。
- 保存処理は `Infrastructure/Storage` の `SecureStorageManager`・`PreferencesManager` に分け、APIClient と並列に Repository へ注入する。Manager には OS ごとの保存実装を注入し、保存キーの選択と Data の組み立ては Repository が担当する。
- DI は `RegzaApp/AppFactory+Repositories.swift`（APIClient・Manager → Repository）、`AppFactory+UseCases.swift`（Repository → UseCase）、`AppFactory+ViewModels.swift`（UseCase → ViewModel）にまとめる。iOS・Android・CLI は共通の Factory を使い、通信と保存先は起動時に渡す。Repository または UseCase の protocol を直接渡せるため、テストでも同じ入口から差し替えられる。
- iOS の終了通知は `RootView` から `AppContainer.applicationWillTerminate()` に渡す。`AppServices/AppLifecycleService` が保存済みの配信先と配信 ID を使い、注入された HTTPTransport で停止を試みる。待機上限は従来どおり 2 秒で、停止できなかった ID は次回起動時の回収用に残す。UI モジュールはこの処理や Infrastructure に依存しない。
- iOS の `AppContainer` は組み立てた `AppViewModel` と Manager を受け取れる。Android は `RegzaAndroidAppFactory.init(OkHttpTransport())` に通信実装を注入し、`makeApp(AndroidStorage(...))` で保存先を渡す。通信実装をグローバルに書き換えず、探索処理にも同じ transport を渡す。
- iOS は `AppServices/Storage` の `KeychainStorage`・`UserDefaultsStorage`、Android は `RegzaAndroidStorage` を共通の保存プロトコルにつなぐアダプターを使う。Android のパスワードは従来どおり Keystore の鍵で暗号化する。既存の保存キー・値の形式と、iOS の旧登録 ID の移行を維持する。
- `RegzaCore` の通信は `HTTPTransport` を通す。iOS と CLI は URLSession、Android は Kotlin の `OkHttpTransport` を使う。Swift 側はリクエストと応答の値を JNI 越しに渡し、HTTP の読み取り・圧縮・DNS・プロキシ・接続管理・TLS は各プラットフォームの通信実装に任せる。通常の HTTPS は Android の信頼ストアとホスト名検証を使う。テレビの 4430 番だけは自己署名を受け入れる既存の例外を維持し、その接続ではリダイレクトを追わない。
- APIClient・探索処理には `HTTPTransport` を明示して渡す。URLSessionTransport は Android ではビルドせず、APK に FoundationNetworking を同梱しない。`build-swift.sh` は梱包対象に FoundationNetworking が残っていれば失敗する。独自の HTTP パーサ・SocketTransport と BoringSSL の静的リンクは使用しない。
- Repository と UseCase は Domain/Data の `ChannelData`・`ProgramData` などを受け渡す。UseCase は Domain に置き、画面側には `RegzaSharedModels` の型を返す。ViewModel は Data を保持せず、番組検索の索引も Domain 内で管理する。
- `Infrastructure/Mappers` は API の型から Data への変換、`Domain/Mappers` は Data から SharedModel への変換を担当する。
- REGZA・Mirakurun・EPGStation の API は `OpenAPI/` の仕様から Swift OpenAPI Generator で生成する。生成クライアント、Digest 認証・LenientJSON のミドルウェア、既存の `HTTPTransport` を包む `ClientTransport` はすべて共有する。構成と生成方法は [OpenAPI/README.md](OpenAPI/README.md)。

## 開発

共通ツールと生成・テスト・ビルドのタスクは、ルートの `mise.toml` で管理する。
普段はルートから `mise run <タスク名>` を実行する。Bunの版もルートに1か所だけ定義する。
生成コード・設定・テストコードはそれぞれのディレクトリに置き、miseのタスクから作業ディレクトリを指定する。

| 設定ファイル | 役割 |
| --- | --- |
| `mise.toml` | 共通ツール（Bun・ktlint）と実行タスク |
| `mise.linux.toml` | Linux用Swiftの選択 |
| `Android/mise.toml` | Android用Swift・JDK・SDKと専用タスク |
| `UITests/mise.toml` | Maestro・JDKと端末でのUIテストの準備・実行 |

Android の APK ビルド・ホストの JVM テストは macOS と Linux を対象にする。Linux の APK ビルドは Android NDK のホストツールに合わせて x86_64 を使う。iOS のビルド・RegzaKit のテストは Xcode が必要なため macOS で行う。Windows ネイティブの開発環境は対象外で、WSL2 は Linux の手順を使う（Windows 側の Android Studio とのプレビュー連携は別途検証が必要）。

Android SDK の場所は `ANDROID_HOME`、次に `ANDROID_SDK_ROOT` を優先し、未指定なら macOS は `~/Library/Android/sdk`、Linux は `~/Android/Sdk` を使う。SDK・NDK は開発ホスト用、APK に入れる Swift の .so は従来どおり Android の arm64-v8a 用で、この 2 つの CPU アーキテクチャは別に扱う。

`mise run check` は iOS のビルドも含むため macOS 用。Linux では `lint`・`test-swift-shared`・`build-android`・`test-behavior` を個別に実行する。

Swift の Android ビルド・ホスト向けビルド・振る舞いテスト用 CLI のビルドは、SwiftSyntax などの初回コンパイルでメモリを多く使うため、並列数を既定で 2 にする。`SWIFT_BUILD_JOBS=1 mise run build-android` のように変更できる。Gradle の JVM メモリは `Android/gradle.properties` で管理する。

Linux のホスト JVM では、`HostSwiftRuntime` が専用スレッドで Swift のライブラリを読み込み、そのスレッドの終了まで待つ。これにより MainActor のキューを JVM の入力待ちや Future の待機から切り離す。振る舞いテストとエディタのプレビューで共通に使い、Android 端末では既存の Looper への接続を使う。

Swift と Xcode の版はルートの `toolchains.toml` で管理する。`swift.version` は Android・Linux の swift.org 版と Android SDK の共通バージョン、`swift.android_sdk_checksum` はその SDK のチェックサム、`xcode.version` は iOS に使う Xcode のバージョン。`Android/mise.toml` とルートの mise タスクはこの設定を参照する。

iOS は Xcode 付属の Apple Swift を使い、`swift.version` と major.minor が同じことを検査する（例: Apple Swift 6.4 と swift.org 6.4.2）。Apple 版と swift.org 版のビルド識別子の一致は要求しない。Android・Linux はリリースタグまで一致させる。Xcode の `SWIFT_VERSION = 6.0` は言語モードであり、このコンパイラの版とは別の設定。

`mise run check-apple-toolchain` で選択中の Xcode と Apple Swift を確認できる。iOS のテスト・ビルドでも先に実行され、不一致なら停止する。ローカルでは使用する Xcode を `DEVELOPER_DIR` または Xcode の選択で指定する。Linux CI は `mise run check-swift-toolchain`、Android は既存の `resolve_swift_toolchain` で版を確認する。Linux CI は `MISE_ENV=linux` で `mise.linux.toml` を読み込み、共通設定の Swift を導入する。CI の Xcode 選択は `mise run select-ci-xcode`、Android SDK の準備は `mise run install-android-swift-sdk` が担当する。SDK は指定版が既にある場合は再インストールせず、CI のキャッシュも共通設定を参照する。版を上げるときは、このファイルで Xcode・Swift・SDK チェックサムの組み合わせを更新し、両環境のテストとビルドを確認する。

Repository・UseCase の単体テストは [Mockolo](https://github.com/uber/mockolo) で生成するモックを使用する。対象は Domain の `@mockable` を付けた protocol。生成結果は `Tests/RegzaCoreTests/Generated/DomainMocks.swift` に置き、protocol を変更したらリポジトリのルートで `mise run generate-mocks` を実行する。Mockolo は `Tools/GenerateMocks/Package.swift` で版を固定し、アプリの依存から分離しているため、通常のアプリビルドやテストで生成ツールをビルドする必要はない。

`Tests/RegzaCoreTests/Support` は、入力値の `DataFixtures.swift`、生成モックの初期値を設定する `RepositoryMocks.swift`、HTTP・保存・本番 Factory をつなぐ `HTTPTestEnvironment.swift`、ViewModel の準備と待機を行う `ViewModelFixtures.swift` に分ける。単体テストの戻り値やエラーはモックの Handler に設定し、呼び出し回数・引数は生成された記録で確認する。通信を含むテストでは本物の Repository と偽の HTTP を使い、画面プレビュー用の SampleRepository とは分ける。

```sh
mise run generate-mocks                  # Domain の protocol を変更したときにモックを再生成
cd Packages/RegzaCore && swift test       # 共有部分のテスト
cd Android/RegzaAndroidBridge && swift test  # Android の窓口のテスト (macOS・Linux)
cd Android/ScreenGlue && swift test       # 窓口のつなぎを作る道具のテストと、Git に入れたつなぎが古くないかの確認
open iOS/RegzaRemote.xcodeproj            # 実機へ入れるときは下の Local.xcconfig を作る

cd Android                                # Android 版（Android Studio はなくてもよい）
mise install                              # Swift のツールチェーン・JDK・Android CLI
mise run setup-android-sdk                # 初回だけ。Android SDK のライセンスを確かめて同意する（Android Studio で SDK を入れていれば要らない）
mise run install-android-swift-sdk        # 初回だけ。Swift SDK for Android（platform・build-tools・NDK は Gradle が入れる）
./gradlew :app:assembleDebug              # Swift の .so と Java のクラスも先に作る (buildSwift が mise run build-swift を呼ぶ)
mise run prepare-android-preview          # エディタの横にプレビューを出すとき。ホスト向けライブラリを別途作る
mise run test-android-runtime             # arm64 のエミュレーター/実機で .so・JNI・Looper・OkHttp・Android TLS を確かめる
./gradlew :app:assembleRelease            # 配るアプリ。作ったあと、APK に手元のフォルダの場所が入っていないことも確かめる (checkReleaseApk)

cd ..                                    # リポジトリのルートへ戻る
mise run test-behavior                    # 振る舞いのテスト (両方の相手をビルドして、同じテストを iOS 側と Android 側で流す)
```

画面の復元対象は iOS・Android で共通の `AppViewModel` が定義する。Android は `RegzaViewModel` の `SavedStateHandle`、iOS は `RootView` の `SceneStorage` と AppServices の `AppStateRestoration` へ接続する。OS の保存時に入力・検索条件・選択中タブ・設定画面・戻る道・番組表の日付と放送種別を小さな JSON にまとめ、新しい ViewModel へ戻す。番組やチャンネルは再取得し、存在しない画面は戻る道から除く。未保存のパスワード・PIN・通信中フラグ・ライブ視聴の実行状態は含めない。保存済み認証情報は従来どおり StorageManager から読む。iOS はシーンが非アクティブ・バックグラウンドへ移る際に退避し、画面の初回表示時だけ読み戻す。Siri や Live Activity による画面のない起動では復元せず、開発用の SampleData では既存の保存状態を上書きしない。

手動では、設定の IP アドレスを保存せずに入力し、「アクティビティを保存しない」をオンにしてホームへ移動したあと、履歴から戻って入力が残ることを確認する。プロセス終了も確認するときは、このオプションを戻してアプリをバックグラウンドに置き、`adb shell am kill com.example.regzaremote` で終了させる。`adb shell pidof com.example.regzaremote` で終了を確認し、履歴から戻ったときに新しい PID で入力が復元されることを確かめる。

### Android 実行環境のスモークテスト

`mise run test-android-runtime` は、`AndroidRuntimeSmokeTest`・`StateLifecycleTest`・`TLSTransportTest`・`StateRestorationTest`・`OkHttpTransportTest` を実機・エミュレーター上で実行する。APK のビルド・インストールも Gradle が行う。上記の Android 開発環境に加え、Android API 28 以上で `arm64-v8a` に対応した端末が必要。エミュレーターは Android Studio の Device Manager で arm64 の AVD を起動する。実機は USB デバッグを有効にし、接続時の認証を許可する。

リポジトリのルートから実行する:

```sh
(cd Android && mise exec -- adb devices -l)  # 対象が device と表示されることを確認する
mise run test-android-runtime
# 複数の端末を接続している場合は、一覧に出たシリアル番号で対象を選ぶ
ANDROID_SERIAL=emulator-5554 mise run test-android-runtime
```

AndroidRuntimeSmokeTest・StateLifecycleTest・TLSTransportTest・StateRestorationTest・OkHttpTransportTest の計 16 件を確認する。テレビ・Mirakurun・EPGStation への接続は不要。

- `swiftLibrariesJniLooperAndFlowCancellation`: APK の .so の読み込み、JNI・Looper を通る state 更新と、Flow を繰り返し終了したあとの待機の解消。
- `earlyCancellationAndStateChangesReleaseWaits`: 初回受信直後の状態変更とキャンセルが重なっても、Swift の待機が残らない。
- `cancellingOneCollectorKeepsOtherCollectorActive`: 同じ state を購読する一方の Flow を止めても、もう一方には変更通知が届く。
- `StateRestorationTest`: Activity 再生成による入力の維持と、Bundle を Parcel に退避して元の ViewModel を破棄したあとの復元。
- `OkHttpTransportTest`: 実際の Swift → JNI → OkHttp でチャンク応答・gzip・URL のクエリ・通常のリダイレクト・タイムアウト・Call の取消を確認する。MockWebServer はテスト APK だけに使用する。
- `TLSTransportTest`: 端末内の TLS サーバーとのハンドシェイクと HTTP 送受信、システム CA で信頼されない自己署名証明書の拒否、信頼済み証明書のホスト名不一致による拒否、テレビの自己署名例外とリダイレクトの抑止。外部通信は行わず、テスト用の信頼先を OkHttp の DI で渡す。
- `stoppedScreenReleasesWaitAndReceivesLatestStateOnRestart`: 実際の rememberState を Compose で動かし、Lifecycle が CREATED に下がると待機が終了し、STARTED に戻ると最新の state を受け取る。

Swift／Java の接続コード、state の待機・キャンセル、Looper、OkHttpTransport、.so の梱包、Swift・swift-java・NDK の版を変更したときに実行する。ホストの JVM の振る舞いテストと併せて確認する。接続済み端末が必要なため、`mise run check` には含めていない。現在の CI の Android ジョブもテスト APK のビルドまでで、端末上での実行は別途行う。

| 失敗した場所 | 確認先 |
| --- | --- |
| 端末が見つからない・インストールできない | `adb devices -l` の状態、USB デバッグの認証、対象の API と ABI。複数台の場合は `ANDROID_SERIAL` を指定する |
| 生成・native ビルド・梱包 | ビルドログの `[build-swift]`。下記「Swift／Java 接続の生成と調査」を参照 |
| テストの失敗・タイムアウト | `Android/app/build/reports/androidTests/connected/debug/index.html` と `Android/app/build/outputs/androidTest-results/connected/debug/` の端末別結果 |
| アプリのクラッシュ・native ライブラリの読み込み失敗 | 対象端末の `adb logcat -d -b crash`。複数台の場合は `adb -s <シリアル番号> logcat -d -b crash` |

### 振る舞いのテスト

Shopify の [Reflex](https://shopify.engineering/reflex) と同じ作りで、画面を描かずに ViewModel の state と操作を確かめる。テストは `BehaviorTests/`（Bun・TypeScript）に 1 回だけ書き、iOS 側と Android 側の 2 つの相手に同じテストを流す。片方だけ通る状態は失敗になる。テストは相手がどちらかを知らず、CLI と同じ約束事（`tree`・`ls`・`do`・`wait` の 1 行ずつの命令と JSON）だけを使う。

- iOS 側の相手は `regza`（iOS と同じ共有の組み立てを macOS・Linux 上の CLI で動かす。iOS アプリそのものは起動しない）
- Android 側の相手は `regza-android`（`Android/behavior-tests`。ホストの JVM）。命令の読み方と返す JSON は `regza` と同じもの（`IntrospectionSession`）を使い、操作を送るところと state を受け取るところだけを、アプリと同じ道（Kotlin の `send` と `xxxStates` → swift-java のつなぎ → 窓口）で行う。窓口とつなぎはホスト向けの共有ライブラリ（`RegzaJVMHost`）にして読み込む。Linux の swiftCore は使用中の Swift ツールチェーンから参照し、`/usr/lib/swift` に固定しない。エミュレーターは使わない
- 外からの入力は見本の返事（`RegzaSample` の `SampleTransport`）で渡すので、テレビにも録画サーバーにもつながない
- テストは `sdk/app.ts` の `describeOnBothPlatforms` で書き、`do`（操作を送り、state が期待どおりになるまで待つ）と `precondition`（state が期待どおりになるまで待つ）で確かめる
- 「テレビにつながらない」「チャンネル一覧が空」のような場面は、`describeOnBothPlatforms` に fixture（`SampleFixture`。宛先ごとの返事の差し替えと、つながらないアドレス）を渡して作る。両方の相手に、起動するときに `--fixture <JSON のファイル>` で渡る
- Swift 6 からは、Android の Foundation も iOS と同じ swift-foundation（JSON・Date・Calendar・URL・書式など）を土台にしているので、Mac で動かしても大半は Android と同じものを通る。Android の土台（ART と JNI・Bionic・Looper で動かす MainActor・APK の中の .so の読み込み）は `AndroidRuntimeSmokeTest` を arm64 のエミュレーターや実機で動かして確かめる。swift-corelibs-foundation に残る部分（RunLoop・Thread など）は、使う経路ごとに端末で確かめる

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

画面の状態と操作は、iOS と Android で同じ ViewModel（`RegzaPresentation`）が持つ。ViewModel は Elm 風で、画面に出すものを `state`、画面からの操作を `send(Action)` で受ける。Android は ViewModel の State と Action の型を swift-java でそのまま Java のクラスにして使い、間の窓口（`Android/RegzaAndroidBridge`）は、道具（`Android/ScreenGlue` の `screen-glue`）が State/ と Action/ のフォルダから作る。画面を足すときに窓口を手で書くことはない。

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

`iOS/RegzaKit/Sources/UI/Screens/<画面>Screen.swift` に `struct <画面>Screen` を置き（`ChannelListScreen`）、`viewModel.state` を見て `viewModel.send(...)` で送る。`RegzaDomain` は import しない（`LayerTests` が確かめる）。

画面の名前は、iOS も Android も共有の ViewModel のフォルダの名前に `Screen` を付けたものにそろえ、1 画面 1 ファイルにする。`Screen` は画面全体にだけ付け、部品（`KeyButton`・`NowPlayingCard` など）には付けない。そろっていることは `RegzaKitTests` の `ScreenNamingTests` が確かめる。

### 4. Android の画面を作る

```sh
cd Android
swift run --package-path ScreenGlue --scratch-path .build/screen-glue -c release screen-glue   # ./gradlew のビルド (mise run build-swift) でも毎回実行される
```

ツールが作るもの（作ったものはコミットする。古いままだと `Android/ScreenGlue` のテスト `committedGlueIsUpToDate` が失敗する）。ツールは Swift のソースを swift-syntax で読み、決まりに合わない置き方（型を書いていないプロパティ、送り先の ViewModel のない Action、1 つのファイルに 2 つの型など）なら止まる:

- 窓口の送る関数（`sendChannelListAction`）と state を返す関数（`channelListState(route:)`・`nextChannelListState(route:after:waitID:)`）: `RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift`。Kotlin の Flow が終わると `endStateWait` で Swift 側の待機も終える
- swift-java の設定の型の一覧（`RegzaAndroid/*.swift-java.config` の `importedModuleStubs`）。どのモジュールにも共通の設定（Java のパッケージなど）は `RegzaAndroid/swift-java.common.config` に 1 回だけ書き、ビルドのときにモジュールごとの設定と重ねる
- Kotlin の送り先 `Send`（`send(ChannelListAction.tune(code))` のように、どの Action も `send` で送れる）と、state の `Flow`（`app.channelListStates(route)`）: ビルドのたびに `.build/swift/screen-glue-kotlin/` に作る

Kotlin の画面は `app/src/main/java/com/example/regzaremote/ui/screens/<画面>Screen.kt` に `fun <画面>Screen(` を置き（`ChannelListScreen`）、自分の ViewModel の state を受け取って描き、操作を `send` で送る。ファイルの末尾にはプレビューを置く。タブの最初の画面なら `ui/navigation/AppRoutes.kt` の `TabRoot`、タブの中で開く画面なら同じファイルの `RouteScreen` に足す。

iOS の `UI/Screens` と Android の `ui/screens` に画面を置き、補助 View はそれぞれ `Components`・`ui/components` に分ける。色・余白などは iOS の `Design`、Android の `design` が担当する。

Android のルートパッケージには起動用の `MainActivity.kt`・`RegzaApplication.kt` を置く。`appservices/AppFactory.kt` が保存先を Swift の Factory に渡し、組み立てた App を Android の ViewModel に注入する。`appservices/RegzaViewModel.kt` は App の保持と終了時の処理、`appservices/storage` は Android Keystore・SharedPreferences を担当する。

UI は `ui/screens`（画面）・`ui/components`（共通 UI・state の購読・権限案内）・`ui/navigation`（タブの戻る道と表示先）・`ui/preview`（プレビューの準備）に分ける。色・テーマは `design/AppTheme.kt`、余白・サイズは `design/Design.kt`、ボタンや見出しなどは `ui/components/CommonComponents.kt` に置く。Gradle モジュールは増やさず、役割を package で区別する。

Swift の接続コードは、生成する Kotlin の `com.example.regzaremote.bridge`（`Send`・`AppSend`・state の Flow）と、Java の `com.example.regzaremote.core` に分ける。生成結果は `.build/` に置く。変更するときは `ScreenGlue` や swift-java の設定を更新し、生成結果を直接編集しない。

Android の Kotlin の依存方向は、`Tools/KtlintRules` の ktlint カスタムルール `regza:dependency-imports` で検査する。`mise run lint` と `mise run format` はルールのテスト・JAR のビルド後に読み込むため、push・PR の Linux CI でも実行される。既存の Gradle wrapper を使い、Android SDK・Swift の生成済みコードは不要。ktlint の版はルートの `mise.toml` からビルドに渡す。

- `ui` から appservices、保存インターフェース、native の生成・変換ユーティリティ、AppSend、BuildConfig、Swift 実行環境、SharedPreferences・DataStore・暗号化保存への import を禁止する。表示用の core の型・Send・state の購読は利用できる。
- appservices・bridge から UI への import、design から UI・appservices・bridge・core への import を禁止する。
- プレビューの生成・保存先・ライブラリ読み込みは `appservices/preview/PreviewAppFactory.kt` に置く。`ui/preview` からはこの Factory のみ利用でき、通常の画面からは参照できない。`SamplePreview.kt` は準備済み App の表示とエラー表示を担当する。
- 配信 URL の変換は `bridge/StreamURL.kt` が担当し、画面から native のユーティリティクラスを直接呼ばない。

ktlint の構文解析を使って package と import を確認する。別名 import・禁止先のワイルドカード import も検出し、コメントや文字列は対象外。違反時はファイル・行番号・依存先を表示する。自動修正はしない。完全修飾名での直接参照・同一 package 内の参照・型解決・package と配置の一致は検査しない。厳密な依存境界が必要になれば Gradle モジュールによる制約を検討する。

```kotlin
rememberState(key) { app.programListStates(route) }?.let { ProgramListScreen(it, back, send) }
```

### 5. 確かめる

```sh
mise run check                             # 全部を順に確かめる (CI と同じ)
```

`mise run check` は、次のタスクを順に流す。1 つだけ流すこともできる。

```sh
mise run lint                              # Swift と Kotlin のコードの書き方 (swift-format と ktlint。直すときは mise run format)
mise run test-swift                        # Swift のパッケージのテスト (test-swift-shared と test-swift-apple)
mise run test-swift-shared                 #   Apple の環境がなくても流せるもの (RegzaCore・RegzaAndroidBridge・ScreenGlue。Linux でも流せる)
mise run test-swift-apple                  #   Xcode が要るもの (RegzaKit)
mise run build-ios                         # iOS のアプリとウィジェットのビルド
mise run build-android                     # Android のアプリとテスト APK のビルド (debug・release。release は APK の中身も確かめる)
mise run prepare-android-preview           # Android Studio のエディタ用にホスト向けライブラリを準備 (macOS・Linux)
mise run test-android-runtime              # 接続済み arm64 端末で AndroidRuntimeSmokeTest を実行 (check には含まない)
mise run test-behavior                     # 振る舞いのテスト (iOS 側と Android 側)
```

エミュレーターや実機が要る `test-android-runtime` は、`check` には入れていない。

GitHub に push すると、GitHub Actions（`.github/workflows/check.yml`）が同じタスクを流す。書き方と `test-swift-shared` は Linux、Xcode が必要な `test-swift-apple`・`build-ios` は macOS で、ジョブに分けて流す。`build-android` と `test-behavior` のジョブ（android）も Linux x86_64 で実行する。初回の Swift ビルドに時間がかかるため、このジョブは GitHub Actions の画面から手で動かしたとき（Run workflow）だけ流す。

画面を足したら、`BehaviorTests/tests/` にもその画面の振る舞いのテストを足す（操作を送り、state が期待どおりになるまで待つ）。

### Swift／Java 接続の生成と調査

入口は `Android/` の `./gradlew :app:assembleDebug`（内部で `scripts/build-swift.sh` を実行）。NDK の版は Gradle、Swift と SDK の版は `toolchains.toml`、Java のパッケージなどは `RegzaAndroid/swift-java.common.config` を参照する。以下のパスは `Android/` からの相対パス。

`mise run build-swift` と `mise run build-jvm-host` は、`scripts/with-build-lock.swift` で同じ OS のファイルロックを取得する。別の Gradle プロセスから起動しても、接続コードの生成・互換対応・native ビルド・梱包を同時実行しない。待機中はログに表示し、終了時には OS がロックを解放する。`.build/swift-build.lock` は使用中に削除しない。生成ファイルを共有するため、ビルドはこれらの mise タスクを通して実行する。

| 段階 | 入力・設定 | 出力 |
| --- | --- | --- |
| 共有モデルの Java 生成 | `../Packages/RegzaCore/Sources/RegzaSharedModels`、swift-java の共通設定 | `.build/swift/regzashared-java/`、`RegzaAndroid/Sources/RegzaSharedJava/Generated/` |
| 画面の型の Java 生成 | `RegzaPresentation` の State/・Action/、`RegzaAndroid/RegzaPresentation.swift-java.config` | `.build/swift/regzapresentation-java/`、`RegzaAndroid/Sources/RegzaPresentationJava/Generated/` |
| 画面の接続コード生成 | `ScreenGlue` が共有の State/・Action/・ViewModel を読む | `Generated/ScreenActions.swift`、`.build/swift/screen-glue-kotlin/`、設定内の型一覧 |
| アプリ窓口の Java 生成 | `RegzaAndroidBridge/Sources/RegzaAndroidBridge`、`RegzaAndroid/RegzaAndroidBridge.swift-java.config` | `.build/swift/regzabridge-java/`、`RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated/` |
| Kotlin へのコールバック生成 | 生成した `RegzaAndroidStorage.java`・`RegzaAndroidHTTPClient.java` と通信の引数の型 | `.build/swift/bridge-callbacks/`、`RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated/JavaCallbacks.swift` |
| native ビルド・梱包 | 接続コード、Swift SDK、NDK | `app/src/main/jniLibs/arm64-v8a/` |

Kotlin が実装する保存先・HTTP のコールバックと通信の引数の型は、`build-swift.sh` の `callback_types` で明示する。public protocol を追加しても自動で公開対象にはしない。追加するときは、Kotlin 側の実装と生成対象を合わせて検討する。

ビルドログの `[build-swift]` に処理段階・モジュール・設定が表示され、Java 生成時には入力と出力も表示される。失敗時は、元のエラーに続いて段階・モジュール・設定・スクリプトの行番号・終了コードが出る。設定は共通設定とモジュール設定を合成した `.build/swift/configs/` を確認する。Foundation の重複除去とコールバック生成は「swift-java 互換対応」と表示し、通常の生成と区別する。

### swift-java の制約と回避策

swift-java（301e3da）には次の制約がある。どれも、守れなければビルドかテストで止まるようにしている。

- 型を書いていないプロパティ（`public var count = 0`）を、警告だけ出して Java にしない。State/ と Action/ の public なプロパティには型を書く（`public var count: Int = 0`）。書いていなければ `screen-glue` が止まる
- Foundation の型（`URL`・`Date`・`Data`・`UUID`）を enum の値（`case ready(url: URL)`）でしか使っていないと、その型の Java のクラスを作らず、javac が失敗する。`URL` は窓口の `regzaURLString` が使うので作られる。ほかの型を enum の値だけで使うときは、窓口などで一度使う
- Foundation の型の Java のクラスを、使うモジュールごとに作る。3 つのモジュール（`RegzaSharedModels`・`RegzaPresentation`・`RegzaAndroidBridge`）は同じ Java のパッケージに出しているので、そのままでは同じ名前の JNI の関数がぶつかってリンクできない。`mise run build-swift` が、前のモジュールにもある型のつなぎを消す（消せない混ざり方なら止まる）。モジュールごとにパッケージを分けると、ぶつからない代わりに `Date` がモジュールごとに別の型になり、モジュールをまたいで渡せなくなる
- 同じ名前で引数の型だけ違う関数を並べられない。窓口の送る関数を `sendChannelListAction` のように型ごとの名前にしているのはこのため（Kotlin からは `Send` を通してどれも `send` で送れる）
- swift-java が何か宣言を Java にできなかったときは、`mise run build-swift` が止まる（`Failed to import`）
- jextract の入力は絶対 file URL に統一する。相対パスを URL として渡すと Linux で同じ extension が重複収集され、Java のメソッド名や定義が重複するため、`build-swift.sh` がパスの解決と URL エンコードを行う。
- Future のキャンセルが Swift Task に伝わらない制約（[swift-java #947](https://github.com/swiftlang/swift-java/issues/947)）に対し、Flow の finally から endStateWait を呼ぶ。StateWaitRegistry は Swift Task のキャンセルでも continuation を起こすが、遅れて届く終了通知を扱うため、waitID と完了記録は維持する。対応版へ更新するときも、開始前・待機中・状態変更との競合を端末テストで確認してから回避策を簡略化する。
- rememberState は collectAsStateWithLifecycle で購読する。画面の Lifecycle が STARTED 未満になると Flow の終了通知で Swift の待機を解放し、再開時は最新値から受け取り直す。エディタのプレビューでは従来どおり初期値を先に取得する。

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

### Maestro による UI テスト

設定入力・画面遷移・入力復元の 3 フローを iOS / Android で実行する。通常の APIClient・通信をローカル HTTP スタブへ接続し、SampleData を注入しない。導入と実行方法は [UITests/README.md](UITests/README.md)。`mise run test-ui-ios` / `mise run test-ui-android` は対象端末 ID を指定して明示的に実行する。
