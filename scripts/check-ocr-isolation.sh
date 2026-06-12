#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if rg -n '^import Vision$' "$ROOT_DIR/ShotLens" --glob '*.swift' --glob '!**/Tools/**'; then
  echo "Main app sources must not import Vision; OCR belongs in the helper process." >&2
  exit 1
fi

if ! rg -n '^import Vision$' "$ROOT_DIR/ShotLens/Tools" --glob '*.swift' >/dev/null; then
  echo "OCR helper must import Vision." >&2
  exit 1
fi

if rg -n '^import NaturalLanguage$|NLLanguageRecognizer' "$ROOT_DIR/ShotLens/Tools/ShotLensOCR.swift"; then
  echo "OCR helper should avoid per-block NaturalLanguage detection on the hot path." >&2
  exit 1
fi

rg -n 'recognitionLevel = \.accurate' "$ROOT_DIR/ShotLens/Tools/ShotLensOCR.swift" >/dev/null
rg -n 'usesLanguageCorrection = true' "$ROOT_DIR/ShotLens/Tools/ShotLensOCR.swift" >/dev/null
rg -n 'normalizedOCRText' "$ROOT_DIR/ShotLens/Core/OCREngine.swift" >/dev/null
rg -n '\\bAl\\b' "$ROOT_DIR/ShotLens/Core/OCREngine.swift" >/dev/null
rg -n '1m tokens' "$ROOT_DIR/ShotLens/Core/OCREngine.swift" >/dev/null

echo "OCR isolation check passed."
