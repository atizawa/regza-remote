#!/bin/bash
# 画面ごとのフォルダの State/ と Action/ に置いた型から、窓口のつなぎを作る (画面を足しても手で書かずに済むようにする)。
#
#   - RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift
#     Action/ の型ごとに、窓口 (RegzaAndroidApp) の送る関数を作る。送り先は、その型を Action にしている ViewModel
#     (ViewModel のファイルの「typealias Action = 型」で決める)。swift-java は同じ名前の関数を並べられないので、
#     名前は型ごとに変える (sendChannelListAction など)
#   - .build/swift/screen-glue-kotlin/Send.kt
#     画面が受け取る送り先 (Send)。どの操作も send(...) で送れるよう型ごとの invoke を並べ、Swift の窓口に送る AppSend も作る
#     (ビルドのたびに作るので保存しない)
#   - RegzaAndroid/RegzaAndroidBridge.swift-java.config の "RegzaPresentation" の行
#     窓口の Java のクラスを作るときに、State/ と Action/ の型を知らせる
#
# mise run build-swift が毎回作り直す。--check を付けると作り直さずに、作ったものが古くないかだけを確かめる
# (窓口のテストが Mac で確かめる)
set -euo pipefail
cd "$(dirname "$0")/.."

view_models=../Packages/RegzaCore/Sources/RegzaPresentation/ViewModels
actions_file=RegzaAndroidBridge/Sources/RegzaAndroidBridge/Generated/ScreenActions.swift
config_file=RegzaAndroid/RegzaAndroidBridge.swift-java.config
kotlin_file=.build/swift/screen-glue-kotlin/Send.kt

fail() { echo "generate-screen-glue: $*" >&2; exit 1; }

# ファイルにある型の名前 (1 つのファイルに 1 つだけ置く)
type_in() {
  local file=$1 kind=$2 names
  names=$(sed -n "s/^public $kind \([A-Za-z0-9_]*\).*/\1/p" "$file")
  [ "$(printf '%s\n' "$names" | grep -c .)" = 1 ] || fail "$file には public $kind を 1 つだけ置いてください"
  echo "$names"
}

stubs=()
actions=""
kotlin_imports=""
kotlin_invokes=""
kotlin_overrides=""
for file in $(find "$view_models" -path '*/State/*.swift' | sort); do
  stubs+=("\"public struct $(type_in "$file" struct) {}\"")
done
for file in $(find "$view_models" -path '*/Action/*.swift' | sort); do
  action=$(type_in "$file" enum)
  stubs+=("\"public enum $action {}\"")
  # Action/ のあるフォルダの ViewModel のうち、この型を Action にしているもの
  screen_dir=$(dirname "$(dirname "$file")")
  view_model_file=$(grep -l "typealias Action = $action\$" "$screen_dir"/*.swift || true)
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
    operator fun invoke(action: $action)"
  kotlin_overrides+="
    override fun invoke(action: $action) = app.send$action(action)"
done

new_actions="// scripts/generate-screen-glue.sh が作る (手で直さない)
import RegzaApp

extension RegzaAndroidApp {${actions}}"

stub_line="    \"RegzaPresentation\": [$(IFS=,; echo "${stubs[*]}" | sed 's/,/, /g')]"
grep -q '^    "RegzaPresentation": ' "$config_file" || fail "$config_file に \"RegzaPresentation\" の行がありません"
new_config=$(awk -v line="$stub_line" '/^    "RegzaPresentation": /{ print line; next } { print }' "$config_file")

if [ "${1:-}" = --check ]; then
  [ "$new_actions" = "$(cat "$actions_file" 2>/dev/null)" ] && [ "$new_config" = "$(cat "$config_file")" ] ||
    fail "窓口のつなぎが古くなっています。Android で scripts/generate-screen-glue.sh を実行してください"
  exit 0
fi
mkdir -p "$(dirname "$actions_file")" "$(dirname "$kotlin_file")"
printf '%s\n' "$new_actions" > "$actions_file"
printf '%s\n' "$new_config" > "$config_file"
printf '%s\n' "// scripts/generate-screen-glue.sh が作る (手で直さない)
package com.example.regzaremote

${kotlin_imports}import com.example.regzaremote.core.RegzaAndroidAction
import com.example.regzaremote.core.RegzaAndroidApp

/** 画面から操作を送る先。アプリ全体の操作 (RegzaAndroidAction) も、画面ごとの操作 (ChannelListAction など) も send(...) で送る */
interface Send {
    /** アプリ全体の操作 */
    operator fun invoke(action: RegzaAndroidAction)${kotlin_invokes}
}

/** Swift の窓口 (RegzaAndroidApp) に送る */
class AppSend(private val app: RegzaAndroidApp) : Send {
    override fun invoke(action: RegzaAndroidAction) = app.send(action)${kotlin_overrides}
}" > "$kotlin_file"
