#!/usr/bin/env bash
# RegzaAndroid を arm64 向けにビルドし (swift-java が Java のクラスも作る)、Swift の実行に要る .so と一緒に app の jniLibs に入れる。
# mise run build-swift から呼ぶ (Gradle の buildSwift が、NDK の版と SDK の場所を渡して呼ぶ)。Android/ で動かす
#   引数: Swift の版 (mise.toml の vars.swift。Swift SDK for Android も同じ版を使う)
set -Eeuo pipefail

# 生成・互換対応・ビルド・梱包のどこで止まったかを、コマンド本来のエラーに添える。
stage="環境の確認"
module="-"
config="-"
report_failure() {
  local status=$1 line=$2
  printf '\n[build-swift] 失敗: %s (module=%s, config=%s, line=%s, exit=%s)\n' \
    "$stage" "$module" "$config" "$line" "$status" >&2
  exit "$status"
}
trap 'report_failure "$?" "$LINENO"' ERR

begin_stage() {
  stage=$1
  module=${2:--}
  config=${3:--}
  printf '\n[build-swift] %s (module=%s, config=%s)\n' "$stage" "$module" "$config"
}

begin_stage "環境の確認"
if [ $# -eq 0 ]; then
  echo "Swift の版を渡してください (mise run build-swift から呼びます)" >&2
  false
fi
swift_version=$1
swift_build_jobs=${SWIFT_BUILD_JOBS:-2}
# NDK の版は Gradle の buildSwift が app/build.gradle.kts の ndkVersion を渡す
if [ -z "${NDK_VERSION:-}" ]; then
  echo "このタスクは ./gradlew から実行してください (NDK の版は Gradle が渡します)" >&2
  false
fi
. scripts/swift-toolchain.sh
resolve_swift_toolchain "$swift_version"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
printf '[build-swift] Android SDK: %s\n[build-swift] Android NDK: %s\n' "$ANDROID_HOME" "$ANDROID_NDK_HOME"
if [ ! -d "$ANDROID_NDK_HOME" ]; then
  # Android CLI は入れるとライセンスに同意したことになるので、同意済みのときだけ入れる
  [ -s "$ANDROID_HOME/licenses/android-sdk-license" ] || {
    echo "Android SDK のライセンスに同意していません。先に mise run setup-android-sdk を実行してください。" >&2
    false
  }
  android --no-metrics --sdk="$ANDROID_HOME" sdk install "ndk/$NDK_VERSION"
fi
# Swift SDK for Android は NDK 27 以上が要る (SDK に付いてくる setup-android-sdk.sh と同じ確かめ方)
ndk_major=$(sed -n 's/^Pkg.Revision = \([0-9]*\).*/\1/p' "$ANDROID_NDK_HOME/source.properties")
if [ "${ndk_major:-0}" -lt 27 ]; then
  echo "NDK $ndk_major は古いため使えません。app/build.gradle.kts の ndkVersion を 27 以上にしてください。" >&2
  false
fi

triple=aarch64-unknown-linux-android28
sdk=swift-$swift_version-RELEASE_android
out=app/src/main/jniLibs/arm64-v8a
# Swift の実行に要る .so は SDK に入っているもの (場所は SwiftPM に聞く)、libc++_shared.so は NDK のもの
resources=$("$SWIFT_COMMAND" sdk configure --show-configuration "$sdk" "$triple" | sed -n 's/^swiftResourcesPath: //p')
runtime="$resources/android"
libcxx=$(ls "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so | head -1)

# swift-java のプラグインは、Swift から消した型の Java のクラスを消さないので、毎回作り直す
rm -rf .build/swift/plugins/outputs/regzaandroid

# swift-java の jextract を動かす。Java にできない宣言 (型を書いていないプロパティや、知らない型を使うものなど) は
# 警告を出すだけで黙って飛ばすので、飛ばしたものがあればビルドを止める
jextract() {
  local log
  log=$("$swift_java" jextract --log-level warning "$@" 2>&1) || { echo "$log" >&2; return 1; }
  if grep -q "Failed to import" <<< "$log"; then
    echo "swift-java が Java にできなかった宣言があります:" >&2
    grep -o "Failed to import: [^;]*;[^(]*" <<< "$log" | sort -u >&2
    return 1
  fi
}

# swift-java は Date や URL などの Foundation の型のつなぎを、使うモジュールごとに Foundation+SwiftJava.swift に作る。
# どのモジュールも Java のパッケージが同じなので、前に作ったモジュールにもある型は消してそちらを使う
# (残すと同じ名前の関数がぶつかってリンクできない)。引数: Swift のつなぎの置き場、Java の置き場、前に作った Java の置き場…
drop_duplicate_foundation() {
  local swift_dir=$1 java_dir=$2 file type dir dropped="" kept=""
  shift 2
  file="$swift_dir/Foundation+SwiftJava.swift"
  [ -f "$file" ] || return 0
  for type in $(sed -n 's/^@_cdecl("Java_com_example_regzaremote_core_\([A-Za-z0-9]*\)__.*/\1/p' "$file" | sort -u); do
    for dir in "$@"; do
      if [ -f "$dir/com/example/regzaremote/core/$type.java" ]; then
        rm "$java_dir/com/example/regzaremote/core/$type.java"
        dropped+=" $type"
        continue 2
      fi
    done
    kept+=" $type"
  done
  [ -z "$dropped" ] && return 0
  # Swift のつなぎは 1 つのファイルにまとめて作られるので、一部の型だけは消せない
  if [ -n "$kept" ]; then
    echo "$file に、ほかのモジュールにもある型 ($dropped) とない型 ($kept) が混ざっていて消せません。" >&2
    return 1
  fi
  rm "$file"
}

# Swift のモジュールの Java のつなぎを作る (Swift のつなぎは RegzaAndroid の Sources/<…>Java/Generated、Java のクラスは .build/swift/<…>-java)。
# 引数: モジュール、Swift の入力のフォルダ、Swift のつなぎの置き場、Java の置き場、先に作ったモジュールの Java の置き場…
# 設定は、どのモジュールにも共通のもの (RegzaAndroid/swift-java.common.config) に、
# モジュールごとのもの (RegzaAndroid/<モジュール>.swift-java.config。なければ共通のものだけ) を重ねる。
# 先に作ったモジュールがあれば、Foundation の型の重なりを消す
extract_module() {
  local module=$1 input=$2 swift_out=$3 java_out=$4 config
  shift 4
  begin_stage "Java・Swift の接続コードの生成" "$module" "$configs/$module.swift-java.config"
  # swift-java は入力を URL として扱う。相対 URL では Linux で同じ extension を重複収集するため、
  # 絶対 file URL に統一する。空白や # を含む開発ディレクトリも URL としてエンコードする。
  input=$(cd "$input" && pwd)
  input=$(jq -nr --arg path "$input" '"file://" + ($path | split("/") | map(@uri) | join("/"))')
  printf '[build-swift] 入力: %s\n[build-swift] 出力: %s, %s\n' "$input" "$swift_out" "$java_out"
  rm -rf "$swift_out" "$java_out" && mkdir -p "$swift_out" "$java_out"
  config=$(swift_java_config "RegzaAndroid/$module.swift-java.config" "$configs/$module.swift-java.config")
  jextract \
    --config "$config" --swift-module "$module" \
    --input-swift "$input" --output-swift "$swift_out" --output-java "$java_out"
  if [ $# -gt 0 ]; then
    begin_stage "swift-java 互換対応: Foundation の重複除去" "$module" "$config"
    drop_duplicate_foundation "$swift_out" "$java_out" "$@"
  fi
}

# swift-java の設定を作る。共通の設定に、モジュールごとの設定 (あれば) を重ねて書き出し、書き出した場所を返す。
# 引数: モジュールごとの設定、書き出す場所
swift_java_config() {
  local module_config=$1 out=$2
  if [ -f "$module_config" ]; then
    jq -s '.[0] * .[1]' RegzaAndroid/swift-java.common.config "$module_config" > "$out"
  else
    cp RegzaAndroid/swift-java.common.config "$out"
  fi
  echo "$out"
}
begin_stage "swift-java の共通設定とモジュール設定の合成"
configs=.build/swift/configs
rm -rf "$configs" && mkdir -p "$configs"
# SwiftPM のプラグイン (RegzaAndroid の Java のつなぎ) は、ソースの中の swift-java.config を読むので、共通の設定をそこに書き出す
# (書き出したものは Git に入れない)
swift_java_config "RegzaAndroid/RegzaAndroid.swift-java.config" RegzaAndroid/Sources/RegzaAndroid/swift-java.config > /dev/null

# iOS と共有のパッケージや窓口のパッケージにはプラグインをかけられないので、Mac で動く swift-java のツールで、ソースを直接読む。
# Android 向けのビルドとはビルドの設定が違い、同じ置き場だと互いのキャッシュを捨て合うので、置き場を分ける
begin_stage "生成ツールのビルド" "swift-java"
swift_java_build=("$SWIFT_COMMAND" build --jobs "$swift_build_jobs" --package-path RegzaAndroid --scratch-path .build/swift-tool -c release --product swift-java)
"${swift_java_build[@]}"
swift_java=$("${swift_java_build[@]}" --show-bin-path)/swift-java

shared_java=.build/swift/regzashared-java
presentation_java=.build/swift/regzapresentation-java
bridge_java=.build/swift/regzabridge-java
bridge_generated=RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated

# 共有の UI の型 (RegzaSharedModels)。すべてそのまま Java のクラスにする
extract_module RegzaSharedModels ../Packages/RegzaCore/Sources/RegzaSharedModels \
  RegzaAndroid/Sources/RegzaSharedJava/Generated "$shared_java"

# 画面の状態と操作の型 (RegzaPresentation の State/・Action/ に置いた型)。ViewModel は Java にできない (MainActor) ので、
# 画面ごとのフォルダの State/ と Action/ に置いた型だけを Java のクラスにする。
# 絞り込みは入力のフォルダからのパスで比べるので、入力は絶対パスで渡す (相対パスだと、どのファイルも外れる)
extract_module RegzaPresentation "$(cd ../Packages/RegzaCore/Sources/RegzaPresentation && pwd)" \
  RegzaAndroid/Sources/RegzaPresentationJava/Generated "$presentation_java" "$shared_java"

# 画面ごとの操作を送る窓口の send と、窓口の設定に書く画面の状態と操作の型を、State/ と Action/ から作り直す
# (Android/ScreenGlue の screen-glue。Swift のソースを swift-syntax で読む)。
# ScreenGlue/.build は swift test (Xcode の Swift) が使うので、置き場を分ける (同じ置き場だと、Swift が変わるたびに作り直す)
begin_stage "画面の接続コードと型一覧の生成" "ScreenGlue"
"$SWIFT_COMMAND" run --jobs "$swift_build_jobs" --package-path ScreenGlue --scratch-path .build/screen-glue -c release screen-glue

# 窓口 (RegzaAndroidBridge の RegzaAndroidApp と、その状態・操作の型)。Mac の swift test で確かめられるよう別のパッケージにしてある
extract_module RegzaAndroidBridge RegzaAndroidBridge/Sources/RegzaAndroidBridge \
  "$bridge_generated" "$bridge_java" "$shared_java" "$presentation_java"
# Kotlin が実装する Swift の protocol (保存先など) を、Swift から呼ぶための包み (Java<protocol の名前>) を作る。
# swift-java はこれを SwiftPM のプラグインでしか作らないので (enableJavaCallbacks)、同じ手順を手で行う:
# jextract が作ったインターフェースを javac でコンパイルし (ほかのモジュールの Java のクラスも参照する)、wrap-java で包む
callbacks=.build/swift/bridge-callbacks
begin_stage "swift-java 互換対応: Kotlin の保存先・通信へのコールバック生成" "RegzaAndroidBridgeJava" "$callbacks/swift-java.config"
rm -rf "$callbacks" && mkdir -p "$callbacks/classes"
# Kotlin が実装する protocol と、引数に使う Swift の型を明示する。
callback_types=(RegzaAndroidStorage RegzaAndroidHTTPClient RegzaAndroidHTTPRequest RegzaAndroidHTTPCompletion)
java_package=$(jq -er '.javaPackage' RegzaAndroid/swift-java.common.config)
for callback_type in "${callback_types[@]}"; do
  callback_interface="$bridge_java/${java_package//.//}/$callback_type.java"
  if [ ! -f "$callback_interface" ]; then
    echo "コールバックの型が生成されていません: $callback_interface" >&2
    false
  fi
done
printf '[build-swift] 出力: %s/JavaCallbacks.swift\n' "$bridge_generated"
find "$bridge_java" -name '*.java' > "$callbacks/sources.txt"
javac @"$callbacks/sources.txt" -d "$callbacks/classes" -parameters \
  -sourcepath "$shared_java:$presentation_java:".build/swift-tool/checkouts/swift-java/SwiftKitCore/src/main/java
jq -n --arg package "$java_package" --args '{classes: ($ARGS.positional | map({key: ($package + "." + .), value: ("Java" + .)}) | from_entries)}' \
  "${callback_types[@]}" > "$callbacks/swift-java.config"
# Optional などの Java の標準の型は、swift-java の SwiftJava モジュールにある包みを使う
"$swift_java" wrap-java --swift-module RegzaAndroidBridgeJava \
  --output-directory "$bridge_generated" --config "$callbacks/swift-java.config" --cp "$callbacks/classes" \
  --single-swift-file-output JavaCallbacks.swift \
  --depends-on SwiftJava="$PWD/.build/swift-tool/checkouts/swift-java/Sources/SwiftJava/swift-java.config"

# Swift のランタイムは共有ライブラリとして入れ、NEEDED をたどって使うものだけを梱包する。
begin_stage "Android native ライブラリのビルド" "RegzaAndroid" "RegzaAndroid/Sources/RegzaAndroid/swift-java.config"
android_build=("$SWIFT_COMMAND" build --jobs "$swift_build_jobs" --package-path RegzaAndroid --scratch-path .build/swift --product RegzaAndroid -c release
  --swift-sdk "$sdk" --triple "$triple")
"${android_build[@]}"
android_products=$("${android_build[@]}" --show-bin-path)

# 入れる候補: libRegzaAndroid.so と swift-java の libSwiftJava.so、SDK の Swift の .so、NDK の libc++_shared.so
begin_stage "APK 用の共有ライブラリの収集と依存解決" "RegzaAndroid"
printf '[build-swift] 出力: %s\n' "$out"
candidates=.build/swift/android-libs
rm -rf "$candidates" && mkdir -p "$candidates"
cp "$android_products"/*.so "$runtime"/*.so "$libcxx" "$candidates/"

# 候補のうち、実際に使われるものだけを入れる (FoundationXML やテスト用のものなど、使っていないものはアプリを大きくするだけ)。
# Java から名前で読み込むもの (RegzaAndroid・SwiftJava・swiftCore) から始めて、各 .so が使う (NEEDED) ものをたどる
readelf=$(ls "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/bin/llvm-readelf | head -1)
rm -rf "$out" && mkdir -p "$out"
cp "$candidates"/libRegzaAndroid.so "$candidates"/libSwiftJava.so "$candidates"/libswiftCore.so "$out/"
while :; do
  added=0
  for needed in $(for lib in "$out"/*.so; do "$readelf" -d "$lib"; done | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort -u); do
    # libc.so などは Android に入っているので候補にない
    if [ -f "$candidates/$needed" ] && [ ! -f "$out/$needed" ]; then
      cp "$candidates/$needed" "$out/"
      added=1
    fi
  done
  [ "$added" = 1 ] || break
done
if [ -f "$out/libFoundationNetworking.so" ]; then
  echo "Android の通信は OkHttp を使います。FoundationNetworking への依存が残っています。" >&2
  false
fi
echo "$(ls "$out" | wc -l | tr -d ' ') 個の .so を $out に入れました。"
