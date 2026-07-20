#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
OCR_HELPER="$BUILD_DIR/shotlens-ocr-selection-filter-helper"
TEST_BINARY="$BUILD_DIR/ocr-selection-filter-smoke"

mkdir -p "$BUILD_DIR"

swiftc \
  -O \
  -target arm64-apple-macosx14.0 \
  -parse-as-library \
  "$ROOT_DIR/ShotLens/Tools/ShotLensOCR.swift" \
  -o "$OCR_HELPER"

swiftc \
  -target arm64-apple-macosx14.0 \
  -parse-as-library \
  "$ROOT_DIR/Tests/OCRSelectionFilterSmoke.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY" "$OCR_HELPER"

rg -n 'let enhancedBlocks = try recognizeEnglishBlocks' "$ROOT_DIR/ShotLens/Tools/ShotLensOCR.swift" >/dev/null
rg -n 'return try recognizeEnglishBlocks\(in: image, sourceImage: image\)' "$ROOT_DIR/ShotLens/Tools/ShotLensOCR.swift" >/dev/null
rg -n 'request\.usesLanguageCorrection = true' "$ROOT_DIR/ShotLens/Tools/ShotLensOCR.swift" >/dev/null
