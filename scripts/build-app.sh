#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CursorUsageMenuBar"
BUNDLE_NAME="CursorUsageMenuBar.app"
BUILD_CONFIG="${1:-release}"

cd "$ROOT"

echo "==> Building $APP_NAME ($BUILD_CONFIG)..."
swift build -c "$BUILD_CONFIG"

ARCH="$(uname -m)"
BINARY_PATH="$ROOT/.build/$ARCH-apple-macosx/$BUILD_CONFIG/$APP_NAME"
APP_DIR="$ROOT/dist/$BUNDLE_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "==> Built: $APP_DIR"
echo "    Run: open \"$APP_DIR\""
