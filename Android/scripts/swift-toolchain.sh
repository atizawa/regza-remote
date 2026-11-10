# mise で固定した Swift を、PATH の並びにかかわらず使う。
# このファイルを source してから resolve_swift_toolchain <version> を呼ぶ。
# 見つけた Swift を SWIFT_COMMAND に入れ、その場所を PATH の先頭に足す。
# 呼ぶ側は set -euo pipefail で動くので、途中のコマンドの失敗で黙って止まらないよう、失敗は自分で確かめて説明を出す
resolve_swift_toolchain() {
  local expected_version="$1"
  # Gradle は、決まった場所に mise がなければ場所なしの "mise" を渡すので、PATH から場所を探す。
  # PATH になければ、Gradle (ルートの build.gradle.kts) と同じ、よく入っている場所から探す
  local mise_executable=${MISE_EXECUTABLE:-mise}
  case "$mise_executable" in
    */*) ;;
    *) mise_executable=$(command -v "$mise_executable" || true) ;;
  esac
  if [ -z "$mise_executable" ]; then
    local candidate
    for candidate in /opt/homebrew/bin/mise /usr/local/bin/mise "$HOME/.local/bin/mise"; do
      if [ -x "$candidate" ]; then mise_executable=$candidate; break; fi
    done
  fi
  if [ -z "$mise_executable" ] || [ ! -x "$mise_executable" ]; then
    echo "mise が見つかりません。mise install を実行できる環境でビルドしてください。" >&2
    return 1
  fi

  # mise が失敗したとき (Swift が入っていない、mise.toml を信頼していない、設定の書き間違いなど) は、mise の説明も一緒に出す
  local swift_executable mise_error
  mise_error=$(mktemp)
  swift_executable=$("$mise_executable" which swift 2>"$mise_error" || true)
  if [ -z "$swift_executable" ] || [ ! -x "$swift_executable" ]; then
    echo "mise から Swift ${expected_version} を見つけられません。Android フォルダで mise install を実行してください。" >&2
    if [ -s "$mise_error" ]; then
      echo "mise の説明:" >&2
      cat "$mise_error" >&2
    fi
    rm -f "$mise_error"
    return 1
  fi
  rm -f "$mise_error"

  # 版を調べるときに出る警告 (libSwiftScan が見つからない) は、ビルドに関係ないので捨てる
  local compiler_tag expected_tag
  compiler_tag=$("$swift_executable" -print-target-info 2>/dev/null | sed -n 's/.*"swiftCompilerTag"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' || true)
  expected_tag="swift-${expected_version}-RELEASE"
  if [ "$compiler_tag" != "$expected_tag" ]; then
    # 日本語の文字が変数名の続きと読まれないよう、変数は {} で囲む
    echo "Swift の版が違います: ${swift_executable} は ${compiler_tag:-(版が分かりません)}、必要なのは ${expected_tag} です。" >&2
    return 1
  fi

  SWIFT_COMMAND=$swift_executable
  export SWIFT_COMMAND
  PATH="$(dirname "$SWIFT_COMMAND"):$PATH"
  export PATH
  echo "Swift toolchain: ${SWIFT_COMMAND} (${compiler_tag})"
}
