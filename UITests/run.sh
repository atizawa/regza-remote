#!/usr/bin/env bash
set -euo pipefail
platform=${1:?ios または android を指定してください}
mkdir -p .build
ready=$(mktemp "$PWD/.build/server.XXXXXX")
UI_TEST_READY_FILE="$ready" bun run server.ts > ".build/server-$platform.log" 2>&1 &
server_pid=$!
cleanup() {
  if [ "$platform" = android ] && [ -s "$ready" ]; then
    mise -C ../Android exec -- adb -s "$ANDROID_SERIAL" reverse --remove "tcp:$(cat "$ready")" >/dev/null 2>&1 || true
  fi
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  rm -f "$ready"
}
trap cleanup EXIT
for attempt in {1..100}; do
  [ ! -s "$ready" ] || break
  kill -0 "$server_pid"
  sleep 0.1
done
[ -s "$ready" ] || { echo 'HTTP スタブが起動しませんでした' >&2; exit 1; }
port=$(cat "$ready")
if [ "$platform" = android ]; then
  device=${ANDROID_SERIAL:?Android のシリアル番号を指定してください}
  app_id=com.example.regzaremote
  mise -C ../Android exec -- adb -s "$device" reverse "tcp:$port" "tcp:$port"
else
  device=${IOS_SIMULATOR_UDID:?iOS シミュレーターの UDID を指定してください}
  app_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" .build/ios/Build/Products/Debug-iphonesimulator/RegzaRemote.app/Info.plist)
fi
maestro --device "$device" test -e "APP_ID=$app_id" -e "TEST_SERVER=127.0.0.1:$port" \
  --test-output-dir ".build/$platform-results" "${2:-flows}"
