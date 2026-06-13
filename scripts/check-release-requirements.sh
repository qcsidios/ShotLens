#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/ShotLens/App/ShotLensApp.swift"
MAIN="$ROOT_DIR/ShotLens/App/MainWindow.swift"
ICON_GENERATOR="$ROOT_DIR/scripts/generate-shotlens-icons.swift"
BUILD_SCRIPT="$ROOT_DIR/scripts/build-local.sh"
DMG_SCRIPT="$ROOT_DIR/scripts/package-dmg.sh"
README="$ROOT_DIR/README.md"
PROJECT="$ROOT_DIR/ShotLens.xcodeproj/project.pbxproj"

rg -n 'APP_VERSION="v1\.0"' "$BUILD_SCRIPT" >/dev/null
rg -n 'BUNDLE_SHORT_VERSION="\$\{APP_VERSION#v\}"' "$BUILD_SCRIPT" >/dev/null
rg -n 'DEPLOY_DIR="\$\{SHOTLENS_DEPLOY_DIR:-\$BUILD_DIR\}"' "$BUILD_SCRIPT" >/dev/null
rg -n '<string>\$BUNDLE_SHORT_VERSION</string>' "$BUILD_SCRIPT" >/dev/null

rg -n 'APP_VERSION="v1\.0"' "$DMG_SCRIPT" >/dev/null
rg -n 'ShotLens-\$APP_VERSION\.dmg' "$DMG_SCRIPT" >/dev/null
rg -n 'SHOTLENS_CODESIGN_IDENTITY:\?' "$DMG_SCRIPT" >/dev/null
rg -n 'SHOTLENS_NOTARY_PROFILE:\?' "$DMG_SCRIPT" >/dev/null
rg -n 'codesign --verify --deep --strict' "$DMG_SCRIPT" >/dev/null
rg -n 'spctl --assess --type execute' "$DMG_SCRIPT" >/dev/null
rg -n 'hdiutil verify' "$DMG_SCRIPT" >/dev/null
rg -n 'notarytool submit' "$DMG_SCRIPT" >/dev/null
rg -n 'stapler staple' "$DMG_SCRIPT" >/dev/null
rg -n 'stapler validate' "$DMG_SCRIPT" >/dev/null
rg -n 'spctl --assess --type open' "$DMG_SCRIPT" >/dev/null
rg -n 'ShotLens-v1\.0\.dmg' "$README" >/dev/null
if rg -n 'ShotLens-V1\.0\.dmg|ShotLens-1\.0\.dmg' "$README" "$BUILD_SCRIPT" "$DMG_SCRIPT"; then
  echo "Release docs and scripts must use ShotLens-v1.0.dmg naming only." >&2
  exit 1
fi

rg -n 'displayVersion' "$MAIN" "$APP" >/dev/null
rg -n '版本 \\\(displayVersion\)|versionLabel|版本 v1\.0' "$MAIN" >/dev/null

rg -n 'import ServiceManagement' "$MAIN" "$APP" >/dev/null
rg -n 'SMAppService\.mainApp' "$MAIN" "$APP" >/dev/null
rg -n '开机自动启动' "$MAIN" >/dev/null
rg -n 'launchAtLogin' "$MAIN" "$APP" >/dev/null

rg -n 'statusItem\(withLength: NSStatusItem\.squareLength\)' "$APP" >/dev/null
rg -n 'let text = "译"' "$APP" "$MAIN" "$ICON_GENERATOR" >/dev/null
if rg -n 'let text = "义"' "$APP" "$MAIN" "$ICON_GENERATOR"; then
  echo "The app and menu bar glyph must use 译, not 义." >&2
  exit 1
fi

for project_file in \
  MainWindow.swift \
  LLMTranslator.swift \
  SelectionClient.swift \
  ShotLensLanguage.swift \
  ShotLensLogger.swift \
  TextLayoutOptimizer.swift \
  TranslationSettings.swift \
  ShotLens.icns \
  ShotLensMenuBarTemplate.png
do
  rg -n "$project_file" "$PROJECT" >/dev/null
done
rg -n 'Resources \*/ = \{' "$PROJECT" >/dev/null
rg -n 'PBXResourcesBuildPhase' "$PROJECT" >/dev/null

echo "Release requirements check passed."
