#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OVERLAY="$ROOT_DIR/ShotLens/Core/OverlayWindow.swift"

if rg -n 'addLocalMonitorForEvents|escapeMonitor|onOutsideTap|✓|checkmark' "$OVERLAY"; then
  echo "Result window must not use local event monitors, click-to-dismiss, or the old checkmark save flow." >&2
  exit 1
fi

echo "Result window stability check passed."
