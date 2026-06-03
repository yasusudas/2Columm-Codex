#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Codex Pixel Terminal"
PROCESS_NAME="CodexPixelTerminal"
BUNDLE_ID="com.yasusu.codexpixelterminal"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/CodexPixelTerminal"
DIST_DIR="$ROOT_DIR/dist"
CACHE_DIR="$ROOT_DIR/.build/codex-pixel-terminal-cache"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PROCESS_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$PACKAGE_DIR/Resources/AppIcon.icns"
PIXEL_AGENTS_SOURCE="$PACKAGE_DIR/Resources/PixelAgents"
PIXEL_AGENTS_DIST="$PIXEL_AGENTS_SOURCE/dist"

while IFS= read -r app_pid; do
  pkill -P "$app_pid" >/dev/null 2>&1 || true
done < <(pgrep -x "$PROCESS_NAME" 2>/dev/null || true)
pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
pkill -f "$ROOT_DIR/pixel-agents-main/dist/cli.js" >/dev/null 2>&1 || true

mkdir -p "$CACHE_DIR/clang" "$CACHE_DIR/swiftpm" "$CACHE_DIR/build"
export CLANG_MODULE_CACHE_PATH="$CACHE_DIR/clang"
export XDG_CACHE_HOME="$CACHE_DIR/xdg"

if [[ ! -d "$PIXEL_AGENTS_DIST/node_modules" ]]; then
  npm ci --omit=dev --ignore-scripts --prefix "$PIXEL_AGENTS_DIST"
fi

swift build --package-path "$PACKAGE_DIR" --scratch-path "$CACHE_DIR/build" -c release
BUILD_BIN_DIR="$(swift build --package-path "$PACKAGE_DIR" --scratch-path "$CACHE_DIR/build" -c release --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_DIR/$PROCESS_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AppIcon.icns"
while IFS= read -r bundle; do
  ditto --norsrc --noextattr "$bundle" "$APP_RESOURCES/$(basename "$bundle")"
done < <(find "$BUILD_BIN_DIR" -maxdepth 1 -name '*.bundle' -type d -print)
ditto --norsrc --noextattr "$PIXEL_AGENTS_SOURCE" "$APP_RESOURCES/PixelAgents"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$PROCESS_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

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
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  --bundle|bundle)
    echo "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--bundle]" >&2
    exit 2
    ;;
esac
