#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_BINARY="$BUILD_DIR/clipboard-manager-smoke"

mkdir -p "$BUILD_DIR"

swiftc \
  "$ROOT_DIR/ShotLens/Core/ClipboardManager.swift" \
  "$ROOT_DIR/Tests/ClipboardManagerSmoke.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"

rg -n -F 'ClipboardManager().copyImageToClipboard(image: captured.image)' \
  "$ROOT_DIR/ShotLens/App/ShotLensApp.swift" >/dev/null

echo "Automatic selection clipboard check passed."
