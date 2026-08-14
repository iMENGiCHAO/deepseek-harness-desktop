#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DeepSeek Harness"
EXEC_NAME="DeepSeekHarnessDesktop"
BUNDLE_ID="com.zhouchao.dsh-desktop"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$EXEC_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
RESOURCES="$APP_CONTENTS/Resources"

pkill -x "$EXEC_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swiftc -O -target x86_64-apple-macosx13.0 \
  -framework AppKit -framework WebKit \
  -o "$ROOT_DIR/build/$EXEC_NAME" \
  "$ROOT_DIR"/Sources/DeepSeekHarnessDesktop/*.swift
BUILD_BINARY="$ROOT_DIR/build/$EXEC_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$INFO_PLIST"

if [[ ! -f "$RESOURCES/AppIcon.icns" ]]; then
  swiftc -O -o "$ROOT_DIR/build/generate_icon" "$ROOT_DIR/script/generate_icon.swift"
  ICON_OUT="$ROOT_DIR/build/AppIcon.iconset" "$ROOT_DIR/build/generate_icon"
  iconutil -c icns "$ROOT_DIR/build/AppIcon.iconset" -o "$RESOURCES/AppIcon.icns"
fi

codesign --force --deep -s - "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXEC_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$EXEC_NAME" >/dev/null && echo "OK: $EXEC_NAME is running"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
