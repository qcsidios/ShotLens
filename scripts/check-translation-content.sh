#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
TEST_BINARY="$BUILD_DIR/translation-content-planner-smoke"

mkdir -p "$BUILD_DIR"

swiftc \
  "$ROOT_DIR/ShotLens/Models/TranslationResult.swift" \
  "$ROOT_DIR/ShotLens/Core/TranslationContentPlanner.swift" \
  "$ROOT_DIR/Tests/TranslationContentPlannerSmoke.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"
