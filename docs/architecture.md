# アーキテクチャ

iOS と Android で、画面の状態と操作のロジックを 1 つの Swift のコードで共有し、画面だけを OS ごとに書く構成。
判断を 1 か所に置けば、画面なしで確かめられ、両 OS が同じ振る舞いになる。画面は OS の作法に合わせたいので共有しない。
モジュール名はこのリポジトリのもので書いているが、構成と決まりはアプリによらない。
フォルダの並びは [repository-structure.md](repository-structure.md)、作業の手順は [development-guide.md](development-guide.md) にある。

## 層

```
画面 (iOS: SwiftUI / Android: Jetpack Compose)
  ↓ state を読み、Action を送る
プレゼンテーション (共有の Swift: ViewModel・State・Action)
  ↓ UseCase を呼ぶ
ドメイン (共有の Swift: UseCase・Repository の約束・Data・SharedModel への変換)
  ↑ Repository を実装する
インフラ (共有の Swift: API クライアント・通信の受け口・保存の受け口・API の型から Data への変換)
```

- 依存は上から下へだけ向ける。ドメインはインフラを知らず、インフラがドメインの約束（protocol）を実装する
- 画面に見せるのは UI の型（`RegzaSharedModels`）と、ViewModel の State と Action だけ。ドメインの型は画面に見せない
  （プレゼンテーションのモジュールはドメインを `package import` で読み込み、公開する部分にドメインの型を出せないようにしている）
- 共有の Swift は Android（Swift SDK for Android）でもビルドするので、Foundation 以外の Apple のフレームワークを使わない
- 通信（`HTTPTransport`）と保存（`SecureStorageManager`・`PreferencesManager` に渡す保存先）は、共有の Swift が受け口だけを持ち、
  実装は OS ごとに起動時に渡す（iOS は URLSession・Keychain・UserDefaults、Android は OkHttp・Keystore・SharedPreferences）
- 組み立て（どの実装を使って ViewModel を作るか）は共有の Factory（`RegzaApp`）に 1 か所だけ置き、iOS・Android・CLI・テストが同じ入口を使う
- 共有の Swift が画面に出す文言（`RegzaStrings`）は、OS が起動時に、そのとき選ばれている言語のものを入れる
- 今の時刻は `Date()` で直接読まず、組み立てが 1 つだけ作って UseCase・Repository・通信に渡す時計（`AppClock`）から読む。
  時刻で決まる判断（放送中か・予約できるか）を、テストで時刻を決めて境目まで確かめられるようにするため。
  ViewModel は持っている UseCase の時計から読む。待つ時間（キーを送ったあとの静かな時間・待ち合わせの期限）は、
  時計の変更に左右されない `ContinuousClock` で測る
- エラーを画面に出す文言にするのは、プレゼンテーションの共通の `ErrorMessage` 1 か所だけにする（`localizedDescription` を画面に出さない）。
  文言はエラーの code（`ErrorCode`）で、「場面ごとの言い換え」→「どの場面でも同じ言い換え」→ エラーの元の文言の順に引く。
  HTTP API が RFC 9457 の problem+json を返したときは、通信がその詳細（`APIProblem`）を読み、種類（`type`）を code にする。
  サーバーの `title`・`detail` は言語や言い方がアプリと合うとは限らないので、画面には出さない。
  API が返す code で分岐するアプリでも、表に code と文言を足すだけで済むようにするため。
  通信（OS ごとの実装）は返事を受け取れなかった理由の種類（`ConnectionFailure`）だけを伝え、OS の文言は使わない。
  OS の文言は言語や言い方が OS ごとに違い、接続先のアドレスが入ることもあるため
- ユーザーの操作の失敗は捨てずに画面に出す。`try?` で失敗を捨ててよいのは、下準備・片付け・機器を探すとき・待つときだけで、
  捨ててよい理由をコメントに書く

## モジュールの対応

モジュールの名前は「機能名＋層」にそろえ、iOS と Android で 1 対 1 に対応させる。名前を見れば機能と層が分かり、両 OS の対応をたどれる。

| 役目 | 共有の Swift | iOS | Android |
| --- | --- | --- | --- |
| 共通の状態と操作 | `PresentationCore` | — | `:presentation:core` |
| 機能ごとの状態と操作 | `<機能>Presentation` | — | `:presentation:<機能>` |
| アプリ全体の状態と操作 | `AppPresentation` | — | `:presentation:app` |
| 機能が共通に使う画面の部品 | — | `UICommon` | `:ui:common` |
| 機能ごとの画面 | — | `<機能>UI` | `:ui:<機能>` |
| 画面の組み立て | — | `AppUI` | `:ui:app` |
| 色・余白・文言 | — | `Design`・`Localization` | `:core:design`・`:core:localization` |
| アプリの組み立て（DI・保存先・通信） | `RegzaApp` | `AppServices` | `:platform:appservices` |
| ロック画面の表示 | — | `LiveActivity` | `:platform:liveupdate` |
| 画面のない入口（ウィジェットなどのボタン） | — | `SystemActions` | `:platform:systemactions` |
| ウィジェット | — | `Widgets` | `:platform:widgets` |
| 音声アシスタント | — | `Shortcuts` | （OS の機能がない） |
| アプリ本体（起動） | — | アプリのターゲット | `:app` |
| Swift を読むための仕組み | — | （要らない） | `:core:bridge` |

- 大文字・小文字は各言語の慣習に合わせる（Swift のモジュールは大文字始まり、Gradle のモジュールと Kotlin の package は小文字）
- OS の機能の名前（Live Activity と Live Updates など）はそろえず、各 OS の名前を使う
- フォルダも役目ごとにまとめる（iOS の `Sources/` は `Core/`・`Platform/`・`UI/`、Android は `core/`・`platform/`・`ui/`）。置き場所で役目が分かり、両 OS を同じ並びでたどれる
- 片方の OS だけ変えたら、もう片方も同じように変える。そろえない違いは下の「[そろえない違い](#そろえない違い)」に書く

## 依存の向き

```
アプリ本体 → 画面の組み立て → 機能の画面 → 共通の画面の部品 → 共通のプレゼンテーション
                   │               └→ 自分の機能のプレゼンテーション
                   └→ Swift の窓口（Android）・アプリ全体のプレゼンテーション・ロック画面の表示（オン・オフの型）
共通の画面の部品 → ロック画面の表示（オン・オフの型。機能の画面には見せない）
アプリ本体 → OS の機能とつなぐ部分 → 共有の Swift
```

図は主な向きだけを書く。正確な依存は `Package.swift`（共有の Swift・iOS）と `build.gradle.kts`（Android）にある。

| 決まり | 守らせているもの |
| --- | --- |
| 機能のプレゼンテーションは、共通だけを読み込み、ほかの機能を読み込まない | 共有の Swift の `Package.swift`（モジュールの依存） |
| 機能の画面は、共通の部品・共通のプレゼンテーション・自分の機能のプレゼンテーションだけを読み込む（iOS はプレビューの `#if DEBUG` の中だけ、アプリ全体のプレゼンテーションと偽物も読み込んでよい） | iOS: `LayerTests`、Android: Gradle のモジュールの依存 |
| 画面・ロック画面の表示・画面のない入口・ウィジェットは、ドメイン・インフラ・共有の組み立てを読み込まない | iOS: `LayerTests`、Android: Gradle のモジュールの依存（Swift のモジュールは見えず、見えるのは窓口の Java だけ）と、`ui` のパッケージには ktlint の規則 `regza:dependency-imports` |
| アプリの組み立ては、画面と画面のない入口を読み込まない | iOS: `LayerTests`、Android: Gradle のモジュールの依存 |
| 画面の組み立ては、アプリ本体を読み込まない | iOS: モジュールの依存、Android: Gradle のモジュールの依存 |
| 偽物（テスト用のサーバー）は、プレビューの中でだけ読み込む | iOS: `LayerTests` とリリース版の検査、Android: debug にだけ入れ、リリース版の検査 |
| 画面の名前が iOS・Android・共有の ViewModel でそろっている | `ScreenNamingTests` |
| 共有の Swift は今の時刻を `Date()` で直接読まない（偽物のサーバーを除く） | `ClockUsageGuardTests` |
| 共有の Swift と Android の橋渡しは、エラーの文言を `localizedDescription` で読まない（`ErrorMessage` を除く） | `ErrorMessageUsageGuardTests` |

決まりの一覧はテストと設定のほうが正しい。ドキュメントには理由を書き、細かい一覧はテストを見る。
ktlint の規則は import だけを見る（完全修飾名での直接の参照・同じ package の中の参照・型の解決は見ない）ので、境界の本体は Gradle のモジュールの依存で守る。
決まりを変えるときは、守らせているもの（テスト・Gradle と SwiftPM の依存・ktlint の規則）と、この文書の決まりと理由を直す。
依存の向きをコンパイルで守り、両 OS をモジュールの単位で対応させるため、OS の機能とつなぐ部分も Android で Gradle のモジュールに分けている。

## 画面の状態と操作

ViewModel は Elm 風にする。画面に出すものを `state`、画面からの操作を `send(Action)` で受ける。

- 1 つの画面に ViewModel・State・Action を 1 つずつ置く（`<機能>Presentation/<画面>/` の下に `<画面>ViewModel`・`State/`・`Action/`）
- 表示の判断（ボタンを出すか、押せるか、保存できるか、入力が正しいか）は State に入れ、画面に式を書かない。
  画面に置いた判断はテストでも CLI でも確かめられず、iOS と Android にそれぞれ書くことになる
- 部品に分けた ViewModel の操作は、親の Action の case に入れて送る（1 つの画面に Action は 1 つ）
- どの ViewModel も、名前と引数の操作を Action にする口（`IntrospectableActions`）を持つ。CLI と振る舞いのテストはこの口で動かし、
  アプリの画面から送れる操作は、どれも CLI からも送れる（`ContractCoverageTests`）
- 画面の復元に保存するもの（入力・選択・戻る道）は機能ごとに決め、アプリ全体の ViewModel がまとめて小さな JSON にする。
  パスワード・PIN・通信中の状態・再生中の状態は保存しない。取得したデータは取り直し、なくなった画面は戻る道から除く
  - 画面を初めて出すときだけ戻し、画面のない起動（ボタンや音声アシスタント）では戻さない（保存先は OS ごとに違う。下の「そろえない違い」）

### 共通・機能ごと・アプリ全体

- 共通（`PresentationCore`）: 処理中の数え方、CLI 向けの口、どの画面からも使う状態（このアプリではテレビとのつながり `RemoteViewModel`）、
  タブと戻る道の型、画面の移り変わりの窓口（`AppNavigator`）
- 機能ごと（`<機能>Presentation`）: 共通だけを使う（ほかの機能を変えても影響が広がらず、機能を足す場所も決まる）。ほかの機能や組み立てから使う関数は `package` にする
- どの画面からも使う状態は、機能に分けずに共通に置く（分けると、1 つの操作が両方を更新し、分け目が不自然になる）
- アプリ全体（`AppPresentation` の `AppViewModel`）: 機能の ViewModel を持ち、タブ・戻る道・シート・復元をまとめる。`AppNavigator` を実装する

## 画面の移り変わり

- タブの戻る道とアプリ全体のシートの状態は、アプリ全体の ViewModel が持つ（復元・CLI・振る舞いのテストから見えるように）。
  それを表示する `NavigationStack`・back stack（Android は Navigation 3）・シートは、組み立て（iOS の `AppUI`・Android の `:ui:app`）が持つ
- 機能の画面は、画面の移り変わりを窓口（`AppNavigator`）に頼むだけにする（`push`・`play`・`closePlayer`・`showNowPlaying`・
  `closeNowPlaying`・`showSettings`）。窓口は頼むだけで、戻る道やシートを出しているかなどの状態は持たない
- 開いた先の画面は組み立てが決める。機能の画面はほかの機能の画面もタブも知らないので、組み立て方を変えればほかの場所でも使える。
  移り変わりの表示も、組み立ての 1 か所に集まる
- プレビューの準備の都合（ほかの機能のデータを先に読むなど）は窓口に入れず、プレビューの準備（`FakePreview` の `prepareRoutes`）の指定にする
- 機能の中だけで完結する移り変わり（設定の中のページなど）は、機能の中に置いてよい
- iOS は窓口を環境値（`appNavigator`）で渡し、Android は機能の送り先（`<機能>Send`）が窓口を受け継ぐ

## OS の機能（ロック画面・ウィジェット・音声アシスタント）

- OS の機能も、画面と同じく共有の ViewModel の state を読み、Action を送る。共有の部分は「何を出すか」を state に入れるだけで、
  OS ごとの口は持たない（ロック画面に出す見出しやボタンも、共有の state の中の型が決め、OS はそれを描くだけにする）
- アプリのプロセスに Swift の組み立て（iOS は `AppViewModel`、Android は窓口 `RegzaAndroidApp`）を 1 つだけ置き（`AppContainer`）、
  画面・ロック画面・閉じている間の更新が同じものを使う（Android のウィジェットのボタンは例外。下の「そろえない違い」）
- 画面のない入口は、操作を送って終わるまで待ち、state を見て結果を返す
- 通信を伴う処理（前回の後片づけなど）は「画面を開いたとき」に呼ぶ。組み立ては通知やボタンで起こされたときにも作られるので、作るときには呼ばない

## 偽物とプレビュー

- 偽物のサーバー（`RegzaFakeServers`）は通信の境界（`HTTPTransport`）に差し込む。本物の API クライアント・Repository から上をそのまま通るので、
  プレビュー・振る舞いのテスト・CLI が、アプリと同じ道を通る（ViewModel や Repository の手前で差し替えると、アプリと違う道を確かめることになる）
- 場面（`FakeScenario`）を名前で選び、1 つのテストだけの差し替えは宛先ごとの返事で足す
- 偽物の返事が本物の API の定義に合うことは、契約のテスト（`FakeServersContractTests`）が確かめる
- 画面のプレビューは、それぞれの画面のファイルの末尾に置き、偽物で組み立てたアプリの state を渡す（準備は `FakePreview`）
- 偽物はリリース版に入れない
  - iOS: 偽物のモジュールはリリースのビルドで中身のないモジュールになり（`REGZA_FAKES_DISABLED`）、画面が偽物を読み込んでよいのは `#if DEBUG` の中だけ
  - Android: 偽物で組み立てる入口は debug の .so とソースにだけ入れ、プレビューの準備は名前で探して呼ぶ（本番の .so と release の APK に入らない）

## Android から共有の Swift を使う

- swift-java で、共有の UI の型と ViewModel の State・Action を、写さずにそのまま Java のクラスにする（ViewModel そのものは MainActor なので Java にしない）
- 窓口（`RegzaAndroidApp`）が ViewModel への送り先と state の待ち受けを持つ。窓口の送り先・state の Flow・機能ごとの送り先とプレビューのアプリは、
  道具（`ScreenGlue`）が State/・Action/ の置き方から作るので、画面を足しても手で書かない
- 型の Java のクラスは、Swift のプレゼンテーションのモジュールと 1 対 1 の Gradle のモジュール（`:presentation:<名前>`）に分けて入れ、
  ほかの機能の型をコンパイルの段階で使えないようにする。Java のパッケージと JNI の名前は変えず、Gradle のモジュールへの分け方だけを変える
  （Java のパッケージを分けると、Foundation の型がモジュールごとに別の型になり、モジュールをまたいで渡せない）
- 機能の画面は、共通の部品（`:ui:common`。共通の `:presentation:core` を見せる）と自分の機能の `:presentation:<機能>` だけに依存し、窓口（`:core:bridge`）は見えない。
  窓口を使うのは、画面の組み立て・アプリの組み立て・ロック画面の表示・画面のない入口（キーを送る窓口の Factory）と、
  共通の部品の中のプレビューの準備（機能の画面には見せない依存）
- state は Kotlin の Flow で受け取る（swift-java の制約への対応は開発ガイド）
- Android の MainActor は、メインスレッドの Looper で動かす

## 名前の決まり

- 画面は、共有の ViewModel のフォルダの名前に `Screen` を付けたものにそろえ、1 画面 1 ファイルにする。部品には `Screen` を付けない
- 依存するオブジェクトの引数・プロパティは、`<役割><型の種類>`（`<役割>ViewModel`・`<役割>UseCase`・`<役割>Repository`・`<役割>Manager`）の形にし、
  何の役割かと、どの層のものかを名前で分かるようにする。取得した値は、型の種類ではなく中身を表す名前（中身の複数形など）にする
- 共有の Swift の Factory は、`AppFactory+Repositories`（API クライアント・Manager → Repository）・`+UseCases`（Repository → UseCase）・
  `+ViewModels`（UseCase → ViewModel）に分ける

## そろえない違い

次の違いは理由があって残している。そろえたら、この表から外す。モジュールがない・要らないものは、上の「モジュールの対応」の表にある。
表の中身はこのアプリのもの。雛形として使うときは入れ替える。

| 違い | iOS | Android | 残す理由 |
| --- | --- | --- | --- |
| 画面に渡すもの | ViewModel | state と送り先 | Android は Swift の観測できるオブジェクトを持てず、JNI 越しに state の値が Flow で届く |
| 移り変わりの伝え方 | 読み書きできる値（Binding）で `NavigationStack` につなぐ | 戻る操作で伝え、back stack に渡す | 各フレームワークの標準の書き方 |
| シートを出しているかの判断 | state の値を読む | その画面の state が届いているかで決める | Android の state はその画面が開いている間だけ届く |
| 設定の出し方 | シート | 画面全体の切り替え | 各 OS の標準の見せ方 |
| 画面の復元の保存先 | `SceneStorage` | `SavedStateHandle` | OS の仕組みの違い。保存する中身（共有の JSON）は同じ |
| プレビューで使えるもの | アプリ全体の ViewModel（`#if DEBUG` の中だけ） | 自分の機能のプレビューのアプリだけ | iOS の画面は ViewModel を受け取るので、プレビューは組み立て済みの ViewModel から取り出す |
| ほかのアプリに移ったときの視聴 | 音声が流れ続ける（バックグラウンドでの再生） | 視聴を閉じ、配信も止める | Android で続けるにはフォアグラウンドサービスが要り大きな作業になる。機能として要るときに取り組む |
| ロック画面の表示 | 番組が終わると、アプリが起こされなくても次の番組の表示に切り替わる。ボタンを多く出せる | 次の番組は、番組の終了後に起こしてもらって取り直してから出す。ボタンは 3 つまで | OS ごとに出せる大きさ・形と、予定の時刻に表示を切り替える仕組みが違う |
| ウィジェットのボタンで送れなかったとき | 何も出さない（アプリのリモコンの画面にはエラーが出る） | 理由を短い通知（Toast）で出す | iOS のウィジェット・ロック画面のボタンからは、知らせを出す仕組みがない |
| ウィジェットのボタン | アプリのプロセスで動き、`AppContainer` の組み立てを使う | ボタンごとに通信の仕組みだけを作ってキーを送る（窓口を作らない） | Android のウィジェットのボタンはアプリと別に起こされ、画面用の窓口を作ると state の購読や後片づけまで始めてしまう |
