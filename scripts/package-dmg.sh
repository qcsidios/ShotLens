#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ShotLens"
APP_VERSION="0.1.0"
BUILD_DIR="$ROOT_DIR/build/release"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/ShotLens-$APP_VERSION.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR"

SHOTLENS_DEPLOY_DIR="$STAGING_DIR" "$ROOT_DIR/scripts/build-local.sh" >/dev/null
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "ShotLens $APP_VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
