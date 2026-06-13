#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ShotLens"
APP_VERSION="${SHOTLENS_APP_VERSION:-$("$ROOT_DIR/scripts/next-release-version.sh")}"
BUILD_DIR="$ROOT_DIR/build/release"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/ShotLens-$APP_VERSION.dmg"
CODESIGN_IDENTITY="${SHOTLENS_CODESIGN_IDENTITY:-}"

if [[ ! "$APP_VERSION" =~ ^v[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Release version must look like v1.1 or v1.1.0, got: $APP_VERSION" >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR"

SHOTLENS_APP_VERSION="$APP_VERSION" SHOTLENS_DEPLOY_DIR="$STAGING_DIR" SHOTLENS_CODESIGN_IDENTITY="$CODESIGN_IDENTITY" "$ROOT_DIR/scripts/build-local.sh" >/dev/null
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/安装说明-右键打开.txt" <<'TXT'
ShotLens 是未经过 Apple 公证的朋友分享版。

安装：
1. 把 ShotLens.app 拖到 Applications（应用程序）文件夹。
2. 第一次打开时，不要双击；请右键点击 ShotLens.app，选择“打开”。
3. 在 macOS 弹窗里再次选择“打开”。

如果仍提示无法打开，可在终端运行：
xattr -dr com.apple.quarantine /Applications/ShotLens.app
TXT

APP_PATH="$STAGING_DIR/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null
if spctl --assess --type execute --verbose=4 "$APP_PATH"; then
  echo "Gatekeeper accepted $APP_PATH"
else
  echo "Gatekeeper rejected the ad-hoc signed app as expected for friend-share builds."
  echo "Recipients should install it and use right-click Open the first time."
fi

rm -f "$DMG_PATH"
hdiutil create \
  -volname "ShotLens $APP_VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null
hdiutil verify "$DMG_PATH" >/dev/null
xattr -cr "$DMG_PATH" 2>/dev/null || true
"$ROOT_DIR/scripts/check-no-private-config.sh" "$DMG_PATH" "$APP_PATH"

echo "$DMG_PATH"
