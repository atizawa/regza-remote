#!/bin/bash
# 画面ごとのフォルダの State/ と Action/ に置いた型から、窓口のつなぎを作る (画面を足しても手で書かずに済むようにする)。
#
#   - RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift
#     画面の Action (ViewModel のファイルに「typealias Action = 型」と書いた型) ごとに、窓口 (RegzaAndroidApp) の送る関数を作る。
#     送り先は、その型を Action にしている ViewModel。swift-java は同じ名前の関数を並べられないので、
#     名前は型ごとに変える (sendChannelListAction など)。
#     ほかの Action の中で使う部品の操作 (SettingsAction.tv の TVSetupAction など) は Java のクラスにするだけで、送る関数は作らない
#     (1 つの画面には 1 つの Action で送る)。どちらでもない型が Action/ にあれば止める
#     あわせて画面の ViewModel (「typealias State = 型」) ごとに、state を返す関数 (channelListState(route:)) と、
#     変わるまで待って返す関数 (nextChannelListState(route:after:waitID:)) を作る。
#     Kotlin の Flow が終わったら waitID を endStateWait に渡し、待っている Swift の Task も終わらせる
#   - .build/swift/screen-glue-kotlin/Send.kt
#     画面が受け取る送り先 (Send)。どの操作も send(...) で送れるよう型ごとの invoke を並べ、Swift の窓口に送る AppSend も作る。
#     state は型ごとに Flow にする (channelListStates(route))。ビルドのたびに作るので保存しない
#   - swift-java の設定の、ほかのモジュールの型の一覧 (importedModuleStubs の行)
#     RegzaPresentation.swift-java.config と RegzaAndroidBridge.swift-java.config の "RegzaSharedModels" の行に
#     RegzaSharedModels の型を、RegzaAndroidBridge.swift-java.config の "RegzaPresentation" の行に State/ と Action/ の型を書く
#     (書いていない型を使うところは、swift-java が黙って飛ばす)
#
# mise run build-swift が毎回作り直す。--check を付けると作り直さずに、作ったものが古くないかだけを確かめる
# (窓口のテストが Mac で確かめる)
set -euo pipefail
cd "$(dirname "$0")/.."

view_models=../Packages/RegzaCore/Sources/RegzaPresentation/ViewModels
shared_models=../Packages/RegzaCore/Sources/RegzaSharedModels
presentation_config=RegzaAndroid/RegzaPresentation.swift-java.config
actions_file=RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift
bridge_config=RegzaAndroid/RegzaAndroidBridge.swift-java.config
kotlin_file=.build/swift/screen-glue-kotlin/ScreenGlue.kt

fail() { echo "generate-screen-glue: $*" >&2; exit 1; }

# ファイルにある型の名前 (1 つのファイルに 1 つだけ置く)。kind は struct・enum などで、"struct|enum" のように並べてもよい。
# 種類も知りたいときは with_kind を付ける ("struct 名前" の形で返す)
type_in() {
  local file=$1 kind=$2 names
  names=$(sed -En "s/^public ($kind) ([A-Za-z0-9_]+).*/\1 \2/p" "$file")
  [ "$(printf '%s\n' "$names" | grep -c .)" = 1 ] || fail "$file には public ${kind//|/・} を 1 つだけ置いてください"
  if [ "${3:-}" = with_kind ]; then echo "$names"; else echo "${names##* }"; fi
}

stubs=()
actions=""
kotlin_imports=""
kotlin_invokes=""
kotlin_flows=""
states=""
contracts=""
kotlin_contract_sends=""
kotlin_contract_states=""
kotlin_overrides=""
for file in $(find "$view_models" -path '*/State/*.swift' | sort); do
  # swift-java は型を書いていないプロパティ (public var count = 0 など) を黙って飛ばすので、型を書いてもらう
  untyped=$(grep -nE '^ *public (var|let) [A-Za-z0-9_]+ *=' "$file" || true)
  [ -z "$untyped" ] || fail "$file のプロパティに型を書いてください (swift-java が飛ばします): $untyped"
  # 状態は struct のほか、段階などを表す enum も置ける (raw value が String の enum は、そのことも書く)
  type_in "$file" 'struct|enum' > /dev/null
  read -r kind name raw < <(sed -En 's/^public (struct|enum) ([A-Za-z0-9_]+)(: String)?.*/\1 \2 \3/p' "$file")
  stubs+=("\"public $kind $name${raw:+: String} {}\"")
done
for file in $(find "$view_models" -path '*/Action/*.swift' | sort); do
  action=$(type_in "$file" enum)
  stubs+=("\"public enum $action {}\"")
  # Action/ のあるフォルダの ViewModel のうち、この型を Action にしているもの
  screen_dir=$(dirname "$(dirname "$file")")
  view_model_file=$(grep -l "typealias Action = $action\$" "$screen_dir"/*.swift || true)
  if [ -z "$view_model_file" ]; then
    # 同じフォルダのほかの Action の部品なら、送る関数は作らない
    grep -lq "($action)" $(ls "$screen_dir"/Action/*.swift | grep -v "/$action.swift\$") 2>/dev/null ||
      fail "$file の $action を Action にしている ViewModel (「typealias Action = $action」) も、使っている Action も $screen_dir にありません"
    continue
  fi
  [ "$(printf '%s\n' "$view_model_file" | grep -c .)" = 1 ] ||
    fail "$screen_dir に「typealias Action = $action」と書いた ViewModel を 1 つだけ置いてください"
  view_model=$(type_in "$view_model_file" "final class")
  actions+="
    /// $view_model に送る
    public func send$action(_ action: $action) {
        Task { @MainActor in self.perform(action) }
    }

    /// $view_model に送る (テストからは、送った順を待たずに直接呼ぶ)
    @MainActor func perform(_ action: $action) {
        route { (\$0 as? $view_model)?.send(action) != nil }
    }
"
  kotlin_imports+="import com.example.regzaremote.core.$action
"
  kotlin_invokes+="
    /** $view_model に送る */
    operator fun invoke(action: $action)
"
  kotlin_overrides+="
    override fun invoke(action: $action) = app.send$action(action)"

  # 画面の ViewModel の state (ViewModel のファイルの「typealias State = 型」)
  state=$(sed -En 's/^ *public typealias State = ([A-Za-z0-9_]+)$/\1/p' "$view_model_file")
  [ -n "$state" ] || fail "$view_model_file に「public typealias State = 型」を書いてください"
  state_function="$(printf '%s' "${state:0:1}" | tr '[:upper:]' '[:lower:]')${state:1}"
  next_function="next${state}"
  states+="
    /// $view_model の state。route を渡せばその画面の ViewModel の、nil なら開いているものの state。開いていなければ nil
    public func $state_function(route: AppRoute?) async -> $state? {
        await MainActor.run { self.state(route: route) { (\$0 as? $view_model)?.state } }
    }

    /// $view_model の state が after から変わるまで待って返す
    public func $next_function(route: AppRoute?, after: $state?, waitID: Int64) async -> $state? {
        await nextState(route: route, after: after, waitID: waitID) { @MainActor in (\$0 as? $view_model)?.state }
    }
"
  kotlin_imports+="import com.example.regzaremote.core.$state
"
  # 振る舞いのテストの Android 側の相手の口 (約束事の操作を Action にできる ViewModel だけ。IntrospectableActions)
  if grep -q "IntrospectableActions" "$view_model_file"; then
    contracts+="
    /// 振る舞いのテストの Android 側の相手: 約束事の操作を $action にする (アプリと同じ道で送るため)。できなければ nil
    public func contract$action(path: String, action: String, arguments: String) async -> $action? {
        await MainActor.run { (try? contractAction(path: path, action: action, arguments: arguments)) as? $action }
    }

    /// 振る舞いのテストの Android 側の相手: $state を regza と同じ JSON にする ($view_model の見せ方を使う)
    public func contract${state}JSON(_ state: $state?) -> String {
        state.map { $view_model.introspectionJSON(of: \$0) }?.json ?? \"null\"
    }
"
    kotlin_contract_sends+="
        \"$view_model\" -> send(contract$action(path, action, arguments).await().orElse(null) ?: return false)"
    kotlin_contract_states+="
    \"$view_model\" -> contract${state}JSON($state_function(Optional.ofNullable(route)).await())"
  fi
  kotlin_flows+="
/** $view_model の state を、変わるたびに流す (route を渡せばその画面の ViewModel の。開いていなければ null) */
fun RegzaAndroidApp.${state_function}s(route: AppRoute? = null): Flow<$state?> = flow {
    var state = $state_function(Optional.ofNullable(route)).await().orElse(null)
    while (true) {
        emit(state)
        state = waitForNextState { waitID ->
            $next_function(Optional.ofNullable(route), Optional.ofNullable(state), waitID)
        }
    }
}
"
done

new_actions="// scripts/generate-screen-glue.sh が作る (手で直さない)
import RegzaApp

// MARK: - 操作

extension RegzaAndroidApp {${actions}}

// MARK: - state

extension RegzaAndroidApp {${states}}

// MARK: - 振る舞いのテストの Android 側の相手

extension RegzaAndroidApp {${contracts}}"

# RegzaSharedModels の型 (raw value が String の enum は、そのことも書く)
shared_stubs=()
for file in $(find "$shared_models" -name '*.swift' | sort); do
  while read -r kind name raw; do
    shared_stubs+=("\"public $kind $name${raw:+: String} {}\"")
  done < <(sed -En 's/^public (struct|enum) ([A-Za-z0-9_]+)(: String)?.*/\1 \2 \3/p' "$file")
done

# 設定の "モジュール名": [...] の行を、型の一覧に置き換えたものを返す
with_stubs() {
  local file=$1 module=$2 line
  shift 2
  line="    \"$module\": [$(IFS=,; echo "$*" | sed 's/{}",/{}", /g')]"
  grep -q "^    \"$module\": " "$file" || fail "$file に \"$module\" の行がありません"
  # 次の行が続くなら、置き換える前と同じく行の終わりに , を付ける
  awk -v module="    \"$module\": " -v line="$line" \
    'index($0, module) == 1 { print line (/,$/ ? "," : ""); next } { print }' "$file"
}
new_presentation_config=$(printf '%s\n' "$(with_stubs "$presentation_config" RegzaSharedModels "${shared_stubs[@]}")")
new_bridge_config=$(with_stubs "$bridge_config" RegzaSharedModels "${shared_stubs[@]}" | {
  tmp=$(mktemp); cat > "$tmp"; with_stubs "$tmp" RegzaPresentation "${stubs[@]}"; rm -f "$tmp"; })

if [ "${1:-}" = --check ]; then
  [ "$new_actions" = "$(cat "$actions_file" 2>/dev/null)" ] &&
    [ "$new_presentation_config" = "$(cat "$presentation_config")" ] && [ "$new_bridge_config" = "$(cat "$bridge_config")" ] ||
    fail "窓口のつなぎが古くなっています。Android で scripts/generate-screen-glue.sh を実行してください"
  exit 0
fi
mkdir -p "$(dirname "$actions_file")" "$(dirname "$kotlin_file")"
printf '%s\n' "$new_actions" > "$actions_file"
printf '%s\n' "$new_presentation_config" > "$presentation_config"
printf '%s\n' "$new_bridge_config" > "$bridge_config"
printf '%s\n' "// scripts/generate-screen-glue.sh が作る (手で直さない)
package com.example.regzaremote

${kotlin_imports}import com.example.regzaremote.core.AppRoute
import com.example.regzaremote.core.RegzaAndroidApp
import java.util.Optional
import java.util.concurrent.CompletableFuture
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.future.await
import kotlinx.coroutines.withContext

/**
 * swift-java の Future は、Kotlin から取り消しても元の Swift Task を取り消さない。
 * 1 回の待機に番号を付け、正常に受け取ったときも Flow が終わったときも Swift 側へ終了を知らせる。
 */
private val stateWaitIDs = AtomicLong()

private suspend fun <State> RegzaAndroidApp.waitForNextState(
    next: (Long) -> CompletableFuture<Optional<State>>,
): State? {
    val waitID = stateWaitIDs.incrementAndGet()
    return try {
        next(waitID).await().orElse(null)
    } finally {
        // 取り消されたコルーチンの finally でも、Swift の continuation を起こし終わるまで待つ
        withContext(NonCancellable) { endStateWait(waitID).await() }
    }
}

/** 画面から操作を送る先。アプリ全体の操作 (AppAction) も、画面ごとの操作 (ChannelListAction など) も send(...) で送る */
interface Send {${kotlin_invokes}}

/** Swift の窓口 (RegzaAndroidApp) に送る */
class AppSend(private val app: RegzaAndroidApp) : Send {${kotlin_overrides}
}
${kotlin_flows}
/** 振る舞いのテストの Android 側の相手: 道の ViewModel の型ごとに、約束事の操作をアプリと同じ道 (send) で送る。送れなければ false */
suspend fun RegzaAndroidApp.contractSend(type: String, path: String, action: String, arguments: String): Boolean {
    val send = AppSend(this)
    when (type) {${kotlin_contract_sends}
        else -> return false
    }
    return true
}

/** 振る舞いのテストの Android 側の相手: 道の ViewModel の型ごとに、アプリと同じ道 (xxxState) で state を受け取り、regza と同じ JSON にする */
suspend fun RegzaAndroidApp.contractStateJSON(type: String, route: AppRoute?): String? = when (type) {${kotlin_contract_states}
    else -> null
}" > "$kotlin_file"
