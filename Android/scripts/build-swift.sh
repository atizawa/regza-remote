#!/usr/bin/env bash
# RegzaAndroid を arm64 向けにビルドし (swift-java が Java のクラスも作る)、Swift の実行に要る .so と一緒に app の jniLibs に入れる。
# mise run build-swift から呼ぶ (Gradle の buildSwift が、NDK の版と SDK の場所を渡して呼ぶ)。Android/ で動かす
#   引数: Swift の版 (mise.toml の vars.swift。Swift SDK for Android も同じ版を使う)
swift_version=${1:?Swift の版を渡してください (mise run build-swift から呼びます)}
set -euo pipefail
# NDK の版は Gradle の buildSwift が app/build.gradle.kts の ndkVersion を渡す
: "${NDK_VERSION:?このタスクは ./gradlew から実行してください (NDK の版は Gradle が渡します)}"
. scripts/swift-toolchain.sh
resolve_swift_toolchain "$swift_version"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
if [ ! -d "$ANDROID_NDK_HOME" ]; then
  # Android CLI は入れるとライセンスに同意したことになるので、同意済みのときだけ入れる
  [ -s "$ANDROID_HOME/licenses/android-sdk-license" ] || {
    echo "Android SDK のライセンスに同意していません。先に mise run setup-android-sdk を実行してください。" >&2
    exit 1
  }
  android --no-metrics --sdk="$ANDROID_HOME" sdk install "ndk/$NDK_VERSION"
fi
# Swift SDK for Android は NDK 27 以上が要る (SDK に付いてくる setup-android-sdk.sh と同じ確かめ方)
ndk_major=$(sed -n 's/^Pkg.Revision = \([0-9]*\).*/\1/p' "$ANDROID_NDK_HOME/source.properties")
if [ "${ndk_major:-0}" -lt 27 ]; then
  echo "NDK $ndk_major は古いため使えません。app/build.gradle.kts の ndkVersion を 27 以上にしてください。" >&2
  exit 1
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
  log=$(.build/swift-tool/out/Products/Release/swift-java jextract --log-level warning "$@" 2>&1) || { echo "$log" >&2; exit 1; }
  if grep -q "Failed to import" <<< "$log"; then
    echo "swift-java が Java にできなかった宣言があります:" >&2
    grep -o "Failed to import: [^;]*;[^(]*" <<< "$log" | sort -u >&2
    exit 1
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
    exit 1
  fi
  rm "$file"
}

# 共有の UI の型 (RegzaSharedModels の RegzaKey・ProgramItem など) の Java のつなぎを作る。iOS と共有のパッケージには
# プラグインをかけられないので、Mac で動く swift-java のツールで、Packages/RegzaCore/Sources/RegzaSharedModels を直接読む
# Android 向けのビルドとはビルドの設定が違い、同じ置き場だと互いのキャッシュを捨て合うので、置き場を分ける
"$SWIFT_COMMAND" build --package-path RegzaAndroid --scratch-path .build/swift-tool -c release --product swift-java
generated=RegzaAndroid/Sources/RegzaSharedJava/Generated
rm -rf "$generated" .build/swift/regzashared-java && mkdir -p "$generated" .build/swift/regzashared-java
# UI で使う型は、すべてそのまま Java のクラスにする
jextract \
  --config RegzaAndroid/RegzaSharedModels.swift-java.config --swift-module RegzaSharedModels \
  --input-swift ../Packages/RegzaCore/Sources/RegzaSharedModels \
  --output-swift "$generated" --output-java .build/swift/regzashared-java

# 画面の状態と操作の型 (RegzaPresentation の ChannelListState など) の Java のつなぎを作る。
# ViewModel は Java にできない (MainActor) ので、画面ごとのフォルダの State/ と Action/ に置いた型だけを Java のクラスにする。
# 絞り込みは入力のフォルダからのパスで比べるので、入力は絶対パスで渡す (相対パスだと、どのファイルも外れる)
presentation_generated=RegzaAndroid/Sources/RegzaPresentationJava/Generated
rm -rf "$presentation_generated" .build/swift/regzapresentation-java && mkdir -p "$presentation_generated" .build/swift/regzapresentation-java
jextract \
  --config RegzaAndroid/RegzaPresentation.swift-java.config --swift-module RegzaPresentation \
  --input-swift "$(cd ../Packages/RegzaCore/Sources/RegzaPresentation && pwd)" \
  --output-swift "$presentation_generated" --output-java .build/swift/regzapresentation-java
drop_duplicate_foundation "$presentation_generated" .build/swift/regzapresentation-java .build/swift/regzashared-java

# 画面ごとの操作を送る窓口の send と、窓口の設定に書く画面の状態と操作の型を、State/ と Action/ から作り直す
scripts/generate-screen-glue.sh

# 窓口 (RegzaAndroidBridge の RegzaAndroidApp と、その状態・操作の型) の Java のつなぎを作る。
# Mac の swift test で確かめられるよう別のパッケージにしてあり、プラグインをかけられないので、同じくツールで作る
bridge_generated=RegzaAndroid/Sources/RegzaAndroidBridgeJava/Generated
rm -rf "$bridge_generated" .build/swift/regzabridge-java && mkdir -p "$bridge_generated" .build/swift/regzabridge-java
jextract \
  --config RegzaAndroid/RegzaAndroidBridge.swift-java.config --swift-module RegzaAndroidBridge \
  --input-swift RegzaAndroidBridge/Sources/RegzaAndroidBridge \
  --output-swift "$bridge_generated" --output-java .build/swift/regzabridge-java
drop_duplicate_foundation "$bridge_generated" .build/swift/regzabridge-java .build/swift/regzashared-java .build/swift/regzapresentation-java
# Kotlin が実装する Swift の protocol (保存先の RegzaAndroidStorage など) を、Swift から呼ぶための包み (JavaRegzaAndroidStorage) を作る。
# swift-java はこれを SwiftPM のプラグインでしか作らないので (enableJavaCallbacks)、同じ手順を手で行う:
# jextract が作ったインターフェースを javac でコンパイルし (ほかのモジュールの Java のクラスも参照する)、wrap-java で包む
callbacks=.build/swift/bridge-callbacks
rm -rf "$callbacks" && mkdir -p "$callbacks/classes"
protocols=$(sed -En 's/^public protocol ([A-Za-z0-9_]+).*/\1/p' RegzaAndroidBridge/Sources/RegzaAndroidBridge/*.swift)
if [ -n "$protocols" ]; then
  find .build/swift/regzabridge-java -name '*.java' > "$callbacks/sources.txt"
  javac @"$callbacks/sources.txt" -d "$callbacks/classes" -parameters \
    -sourcepath .build/swift/regzashared-java:.build/swift/regzapresentation-java:.build/swift/checkouts/swift-java/SwiftKitCore/src/main/java
  classes=$(for protocol in $protocols; do printf '"com.example.regzaremote.core.%s":"Java%s",' "$protocol" "$protocol"; done)
  echo '{"classes":{'"${classes%,}"'}}' > "$callbacks/swift-java.config"
  # Optional などの Java の標準の型は、swift-java の SwiftJava モジュールにある包みを使う
  log=$(.build/swift-tool/out/Products/Release/swift-java wrap-java --swift-module RegzaAndroidBridgeJava \
    --output-directory "$bridge_generated" --config "$callbacks/swift-java.config" --cp "$callbacks/classes" \
    --single-swift-file-output JavaCallbacks.swift \
    --depends-on SwiftJava="$PWD/.build/swift/checkouts/swift-java/Sources/SwiftJava/swift-java.config" 2>&1) || { echo "$log" >&2; exit 1; }
fi

# Swift のライブラリは埋め込まずに共有ライブラリとして入れる (埋め込むと FoundationNetworking が OpenSSL とリンクできない)。
# HTTPS に使う BoringSSL は、SDK の静的ライブラリ (libssl.a・libcrypto.a) を RegzaAndroid に埋め込む
static_libs=$("$SWIFT_COMMAND" sdk configure --show-configuration "$sdk" "$triple" | sed -n 's/^swiftStaticResourcesPath: //p')/android
"$SWIFT_COMMAND" build --package-path RegzaAndroid --scratch-path .build/swift --product RegzaAndroid -c release \
  --swift-sdk "$sdk" --triple "$triple" -Xlinker -L"$static_libs"

# 入れる候補: libRegzaAndroid.so と swift-java の libSwiftJava.so、SDK の Swift の .so、NDK の libc++_shared.so
candidates=.build/swift/android-libs
rm -rf "$candidates" && mkdir -p "$candidates"
cp .build/swift/out/Products/Release-android-aarch64/*.so "$runtime"/*.so "$libcxx" "$candidates/"

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
echo "$(ls "$out" | wc -l | tr -d ' ') 個の .so を $out に入れました。"
