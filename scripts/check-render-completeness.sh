#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERLAY="$ROOT/ShotLens/Core/OverlayWindow.swift"
LAYOUT="$ROOT/ShotLens/Core/TextLayoutOptimizer.swift"
TRANSLATOR="$ROOT/ShotLens/Core/LLMTranslator.swift"
OCR_HELPER="$ROOT/ShotLens/Tools/ShotLensOCR.swift"
MODELS="$ROOT/ShotLens/Models/TranslationResult.swift"

require_pattern() {
  local pattern="$1"
  local message="$2"
  local file="${3:-$OVERLAY}"
  if ! grep -Fq "$pattern" "$file"; then
    echo "FAIL: $message" >&2
    exit 1
  fi
}

forbid_pattern() {
  local pattern="$1"
  local message="$2"
  local file="${3:-$OVERLAY}"
  if grep -Fq "$pattern" "$file"; then
    echo "FAIL: $message" >&2
    exit 1
  fi
}

require_pattern "textLayout(for text: String, baseRect: CGRect, consistentFontSize: CGFloat)" \
  "translated block layout must be constrained to the original OCR rectangle"
require_pattern "containedRenderRect(for baseRect: CGRect)" \
  "translated block background must stay inside the original OCR rectangle"
require_pattern "fontThatFits(text: String" \
  "layout must shrink font size to fit translated text inside the original rectangle"
require_pattern "enum TextLayoutKind" \
  "OCR layout optimizer must explicitly classify short text, menu/list rows, paragraphs, articles, and mixed captures" \
  "$LAYOUT"
require_pattern "case menuList" \
  "menu/list captures must use a row-preserving layout kind" \
  "$LAYOUT"
require_pattern "case shortText" \
  "short isolated text must use a non-merging layout kind" \
  "$LAYOUT"
require_pattern "case paragraph" \
  "paragraph captures must use a paragraph-aware layout kind" \
  "$LAYOUT"
require_pattern "case article" \
  "article captures must use an article-aware layout kind" \
  "$LAYOUT"
require_pattern "case mixed" \
  "mixed screenshots must use local layout decisions instead of global merging" \
  "$LAYOUT"
require_pattern "preservesIndividualRows" \
  "menu/list rows must be preserved as individual translation blocks" \
  "$LAYOUT"
require_pattern "TextBlockVisualStyle" \
  "OCR text blocks must carry visual style metadata for semantic grouping" \
  "$MODELS"
require_pattern "visualStyle" \
  "layout optimizer must use visual style metadata when grouping OCR blocks" \
  "$LAYOUT"
require_pattern "isLikelyIconBlock" \
  "layout optimizer must skip icon-like OCR noise before translation" \
  "$LAYOUT"
require_pattern "candidate.confidence" \
  "OCR helper must pass Vision confidence into layout metadata" \
  "$OCR_HELPER"
require_pattern "estimateVisualStyle" \
  "OCR helper must estimate text color/depth from the captured pixels" \
  "$OCR_HELPER"
require_pattern "consistentFontSize" \
  "rendering must use a consistent local font size before per-block shrinking"
require_pattern ".regular" \
  "ordinary translated UI text should use regular weight instead of mixing bold and regular weights"
forbid_pattern "softAvailableHeight" \
  "layout must not expand into space before the next block"
forbid_pattern "hardAvailableHeight" \
  "layout must not expand into remaining selected image area"
forbid_pattern "preferredWidth(for text: String" \
  "layout must not widen translated blocks beyond the original OCR rectangle"
require_pattern ".foregroundColor: NSColor.white" \
  "retry button text must stay visible on the dark status pill"
require_pattern "setToggle" \
  "status pill must offer original/translation switching after translation completes"
require_pattern "显示原文" \
  "translated result must expose a button to show the original screenshot"
require_pattern "显示翻译" \
  "original view must expose a button to show the translation again"
require_pattern "StatusSaveButton" \
  "status pill must expose a check icon button for saving the current screenshot"
require_pattern "OverlaySaveWindow" \
  "save screenshot control must live in its own separate floating button window"
require_pattern "drawSaveIcon" \
  "save screenshot control must be drawn as an icon instead of text"
require_pattern "acceptsFirstMouse" \
  "status buttons must accept the first click instead of only activating their floating window"
require_pattern "NSColor.systemGreen" \
  "save screenshot button must be green and visually distinct from the status pill"
require_pattern "copyCurrentSnapshotToClipboard" \
  "save screenshot control must copy the current overlay snapshot"
require_pattern "dismiss()" \
  "saving to clipboard must close the overlay like an outside click"
require_pattern "renderToImage()" \
  "overlay content must be renderable into a clipboard screenshot"
require_pattern "ClipboardManager().copyToClipboard" \
  "saved screenshot must be written to the system clipboard"
forbid_pattern "private let saveButton" \
  "save screenshot button must not be embedded inside the status pill"
forbid_pattern "addSubview(saveButton)" \
  "save screenshot button must be visually separated from the status pill"
require_pattern "mouseDownCanMoveWindow" \
  "floating selected screenshot result must be draggable"
require_pattern "windowDidMove" \
  "status controls must follow the draggable result window"
require_pattern "Do not omit, truncate, merge, summarize, or explain." \
  "LLM translation prompt must explicitly forbid omissions and summaries" \
  "$TRANSLATOR"

echo "render completeness checks passed"
