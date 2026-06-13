#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ShotLens"
APP_VERSION="v1.0"
BUILD_DIR="$ROOT_DIR/build/release"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/ShotLens-$APP_VERSION.dmg"
CODESIGN_IDENTITY="${SHOTLENS_CODESIGN_IDENTITY:?Set SHOTLENS_CODESIGN_IDENTITY to a Developer ID Application signing identity before packaging a public DMG.}"
NOTARY_PROFILE="${SHOTLENS_NOTARY_PROFILE:?Set SHOTLENS_NOTARY_PROFILE to an Apple notarytool keychain profile before packaging a public DMG.}"

rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR"

SHOTLENS_DEPLOY_DIR="$STAGING_DIR" SHOTLENS_CODESIGN_IDENTITY="$CODESIGN_IDENTITY" "$ROOT_DIR/scripts/build-local.sh" >/dev/null
ln -s /Applications "$STAGING_DIR/Applications"

APP_PATH="$STAGING_DIR/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null
spctl --assess --type execute --verbose=4 "$APP_PATH"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "ShotLens $APP_VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --verbose=4 "$DMG_PATH"

echo "$DMG_PATH"
