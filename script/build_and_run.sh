#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DeepSeek Harness"
EXEC_NAME="DeepSeekHarnessDesktop"
BUNDLE_ID="com.zhouchao.dsh-desktop"
MIN_SYSTEM_VERSION="13.0"
VERSION="1.0.0"

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

build_binary() {
  local target="$1"
  local output="$2"
  swiftc -O -target "$target" \
    -framework AppKit -framework WebKit \
    -o "$output" \
    "$ROOT_DIR"/Sources/DeepSeekHarnessDesktop/*.swift
}

make_icon() {
  local source="$ROOT_DIR/Resources/AppIconSource.jpg"
  local icns="$ROOT_DIR/build/AppIcon.icns"
  if [[ ! -f "$icns" || "$source" -nt "$icns" ]]; then
    swiftc -O -o "$ROOT_DIR/build/generate_icon" "$ROOT_DIR/script/generate_icon.swift"
    ICON_OUT="$ROOT_DIR/build/AppIcon.iconset" ICON_SOURCE="$source" "$ROOT_DIR/build/generate_icon"
    iconutil -c icns "$ROOT_DIR/build/AppIcon.iconset" -o "$icns"
  fi
}

stage_app() {
  local binary="$1"
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$RESOURCES"
  cp "$binary" "$APP_BINARY"
  chmod +x "$APP_BINARY"
  cp "$ROOT_DIR/Resources/Info.plist" "$INFO_PLIST"
  make_icon
  cp "$ROOT_DIR/build/AppIcon.icns" "$RESOURCES/AppIcon.icns"
  codesign --force --deep -s - "$APP_BUNDLE"
}

build_native() {
  local arch
  arch="$(uname -m)"
  build_binary "$arch-apple-macosx13.0" "$ROOT_DIR/build/$EXEC_NAME"
  stage_app "$ROOT_DIR/build/$EXEC_NAME"
}

build_universal() {
  build_binary "x86_64-apple-macosx13.0" "$ROOT_DIR/build/$EXEC_NAME-x86_64" &
  build_binary "arm64-apple-macosx13.0" "$ROOT_DIR/build/$EXEC_NAME-arm64" &
  wait
  lipo -create \
    "$ROOT_DIR/build/$EXEC_NAME-x86_64" \
    "$ROOT_DIR/build/$EXEC_NAME-arm64" \
    -output "$ROOT_DIR/build/$EXEC_NAME"
  stage_app "$ROOT_DIR/build/$EXEC_NAME"
}

package_release() {
  local tag="macOS-universal"
  local zip="$DIST_DIR/DeepSeek-Harness-Desktop-$VERSION-$tag.zip"
  local dmg="$DIST_DIR/DeepSeek-Harness-Desktop-$VERSION-$tag.dmg"
  ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$zip"
  hdiutil create -volname "DeepSeek Harness" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$dmg" >/dev/null
  echo "Release packages ready:"
  echo "  $zip"
  echo "  $dmg"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    build_native
    open_app
    ;;
  release|--release)
    build_universal
    package_release
    ;;
  --debug|debug)
    build_native
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_native
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXEC_NAME\""
    ;;
  --telemetry|telemetry)
    build_native
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    build_native
    open_app
    sleep 2
    pgrep -x "$EXEC_NAME" >/dev/null && echo "OK: $EXEC_NAME is running"
    ;;
  *)
    echo "usage: $0 [run|release|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
