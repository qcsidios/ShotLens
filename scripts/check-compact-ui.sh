#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAIN_WINDOW="$ROOT_DIR/ShotLens/App/MainWindow.swift"

rg -n 'apiDetailsExpandedKey' "$MAIN_WINDOW" >/dev/null
rg -n 'apiDetailsContainer' "$MAIN_WINDOW" >/dev/null
rg -n 'isApiDetailsExpanded = UserDefaults.standard.bool' "$MAIN_WINDOW" >/dev/null
rg -n 'toggleAPIExpandedClicked' "$MAIN_WINDOW" >/dev/null
rg -n 'updateWindowHeight' "$MAIN_WINDOW" >/dev/null
rg -n 'startUpdateButtonRotation' "$MAIN_WINDOW" >/dev/null
rg -n 'stopUpdateButtonRotation' "$MAIN_WINDOW" >/dev/null
rg -n 'CABasicAnimation' "$MAIN_WINDOW" >/dev/null
rg -n 'checkUpdateIconView' "$MAIN_WINDOW" >/dev/null
rg -n 'anchorPoint = CGPoint\(x: 0\.5, y: 0\.5\)' "$MAIN_WINDOW" >/dev/null
rg -n 'flushPendingSave\(\)' "$MAIN_WINDOW" >/dev/null
rg -n 'syncAPIKeyDraftFromField' "$MAIN_WINDOW" >/dev/null
rg -n 'NSButton\(title: "清空"' "$MAIN_WINDOW" >/dev/null
rg -n 'NSButton\(title: "恢复默认"' "$MAIN_WINDOW" >/dev/null
rg -n 'NSButton\(title: "测试"' "$MAIN_WINDOW" >/dev/null
rg -n 'apiDefaultNoteLabel' "$MAIN_WINDOW" >/dev/null

if rg -n '截图翻译控制台' "$MAIN_WINDOW" >/dev/null; then
  echo "Main window should not repeat 截图翻译控制台 in the header." >&2
  exit 1
fi

echo "Compact UI check passed."
