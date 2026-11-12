#!/usr/bin/env bash
set -euo pipefail

platform=${1:?apple または swift を指定してください}
expected_swift=${2:?toolchains.toml の Swift の版を指定してください}

case "$platform" in
  apple)
    expected_xcode=${3:?toolchains.toml の Xcode の版を指定してください}
    actual_xcode=$(xcodebuild -version | sed -n 's/^Xcode //p')
    if [ "$actual_xcode" != "$expected_xcode" ]; then
      echo "Xcode の版が違います: ${actual_xcode}、必要なのは ${expected_xcode} です。DEVELOPER_DIR または Xcode の選択を確認してください。" >&2
      exit 1
    fi
    compiler_info=$(xcrun swiftc -print-target-info)
    actual_swift=$(printf '%s\n' "$compiler_info" | sed -n 's/.*"compilerVersion"[[:space:]]*:[[:space:]]*"Apple Swift version \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
    expected_series=${expected_swift%.*}
    if [ "$actual_swift" != "$expected_series" ]; then
      echo "Apple Swift の系列が違います: ${actual_swift:-(不明)}、Android・Linux と共通の ${expected_series} 系が必要です。" >&2
      exit 1
    fi
    echo "Xcode ${actual_xcode} / Apple Swift ${actual_swift} (swift.org ${expected_swift} と同じ系列)"
    ;;
  swift)
    compiler_info=$(swiftc -print-target-info)
    actual_tag=$(printf '%s\n' "$compiler_info" | sed -n 's/.*"swiftCompilerTag"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    expected_tag="swift-${expected_swift}-RELEASE"
    if [ "$actual_tag" != "$expected_tag" ]; then
      echo "Swift の版が違います: ${actual_tag:-(不明)}、必要なのは ${expected_tag} です。" >&2
      exit 1
    fi
    echo "Swift ${actual_tag}"
    ;;
  *)
    echo "不明なプラットフォーム: ${platform} (apple または swift を指定してください)" >&2
    exit 1
    ;;
esac
