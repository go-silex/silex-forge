#!/usr/bin/env bash
# gen-og-images.sh — screenshot each forge artifact → site/a/<slug>/og.jpg
#
# Stack (no Python):
#   jq           — registry JSON
#   google-chrome|chromium — headless screenshot 1200×630
#   ffmpeg       — PNG → progressive JPEG (q default 5 ≈ ~q80 libjpeg)
#
# Usage (repo root):
#   plugins/silex-forge/scripts/gen-og-images.sh
#   plugins/silex-forge/scripts/gen-og-images.sh --slug passation-2026-07 --force
#   plugins/silex-forge/scripts/gen-og-images.sh --quality 4
#
# Idempotent: skip if og.jpg newer than index.html (unless --force).
# Best-effort: missing chrome/ffmpeg → exit 0 + warn (publish continues).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REG="$ROOT/registry"
SITE="$ROOT/site"
W=1200
H=630
QUALITY=5   # ffmpeg -q:v for mjpeg/mjpeg-ish: 2=best, 5≈good, 10=small
FORCE=0
SLUG_FILTER=""

die()  { echo "✗ $*" >&2; exit 1; }
warn() { echo "  ⚠ $*" >&2; }
ok()   { echo "✓ $*"; }
info() { echo "▸ $*"; }

usage() {
  cat <<EOF
Usage: gen-og-images.sh [--slug SLUG] [--force] [--quality N]
  --quality  ffmpeg -q:v 2..12 (default 5; lower = larger/better)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --slug)    SLUG_FILTER="${2-}"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    --quality) QUALITY="${2-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "option inconnue: $1" ;;
  esac
done

# ── deps ──────────────────────────────────────────────────────────
CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then CHROME="$c"; break; fi
done
# Playwright-cached chromium as last resort
if [ -z "$CHROME" ]; then
  for bin in "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux*/chrome; do
    if [ -x "$bin" ]; then CHROME="$bin"; break; fi
  done
fi

if [ -z "$CHROME" ]; then
  warn "no chrome/chromium — skip OG images"
  exit 0
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  warn "ffmpeg missing — skip OG images"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  warn "jq missing — skip OG images"
  exit 0
fi
if [ ! -d "$REG" ]; then
  warn "no registry/ at $REG"
  exit 0
fi

# ── helpers ───────────────────────────────────────────────────────
is_stale() {
  local html="$1" jpg="$2"
  [ ! -f "$jpg" ] && return 0
  # stale if html newer than jpg
  [ "$html" -nt "$jpg" ]
}

# Render one HTML file → og.jpg next to it
render_one() {
  local slug="$1" html="$2"
  local dir
  dir="$(dirname "$html")"
  local out="$dir/og.jpg"
  local tmp_png="$dir/.og-tmp-$$.png"
  local tmp_html="$dir/.og-render-$$.html"
  local tmp_jpg="$dir/.og-tmp-$$.jpg"

  # Temp HTML: strip forge share-bar (would clutter the thumb)
  if grep -q 'forge-share-bar' "$html" 2>/dev/null; then
    # shellcheck disable=SC2016
    sed '/<!-- forge-share-bar -->/,/<!-- \/forge-share-bar -->/d' "$html" >"$tmp_html" \
      || cp "$html" "$tmp_html"
  else
    cp "$html" "$tmp_html"
  fi

  local url="file://${tmp_html}"
  # Headless Chrome — virtual-time-budget waits for fonts/layout (~ms of virtual time)
  if ! "$CHROME" \
      --headless=new \
      --disable-gpu \
      --no-sandbox \
      --hide-scrollbars \
      --force-device-scale-factor=1 \
      --window-size="${W},${H}" \
      --virtual-time-budget=8000 \
      --run-all-compositor-stages-before-draw \
      --screenshot="$tmp_png" \
      "$url" >/dev/null 2>&1; then
    warn "$slug: chrome screenshot failed"
    rm -f "$tmp_png" "$tmp_html" "$tmp_jpg"
    return 1
  fi

  if [ ! -s "$tmp_png" ]; then
    warn "$slug: empty screenshot"
    rm -f "$tmp_png" "$tmp_html" "$tmp_jpg"
    return 1
  fi

  # Compress PNG → JPEG (no intermediate PNG committed)
  if ! ffmpeg -y -loglevel error -i "$tmp_png" \
      -frames:v 1 -q:v "$QUALITY" "$tmp_jpg" 2>/dev/null; then
    warn "$slug: ffmpeg jpeg failed"
    rm -f "$tmp_png" "$tmp_html" "$tmp_jpg"
    return 1
  fi

  mv -f "$tmp_jpg" "$out"
  rm -f "$tmp_png" "$tmp_html" "$dir/og.png"  # drop legacy fat PNG
  local kb
  kb=$(( $(wc -c <"$out") / 1024 ))
  echo "  ✓ $slug → site/a/${slug}/og.jpg (${kb} kb, q=${QUALITY})"
  return 0
}

# ── main ──────────────────────────────────────────────────────────
rendered=0
failed=0
up_to_date=0
total_kb=0

shopt -s nullglob
for reg in "$REG"/*.json; do
  slug="$(jq -r '.slug // empty' "$reg")"
  [ -n "$slug" ] || continue
  if [ -n "$SLUG_FILTER" ] && [ "$slug" != "$SLUG_FILTER" ]; then
    continue
  fi

  path="$(jq -r '.path // empty' "$reg")"
  [ -n "$path" ] || path="/a/${slug}/"
  rel="${path#/}"
  rel="${rel%/}"
  html="$SITE/${rel}/index.html"
  if [ ! -f "$html" ]; then
    html="$SITE/a/${slug}/index.html"
  fi
  if [ ! -f "$html" ]; then
    warn "skip $slug: no index.html"
    continue
  fi

  jpg="$(dirname "$html")/og.jpg"
  if [ "$FORCE" -eq 0 ] && ! is_stale "$html" "$jpg"; then
    up_to_date=$((up_to_date + 1))
    continue
  fi

  if render_one "$slug" "$html"; then
    rendered=$((rendered + 1))
    total_kb=$((total_kb + $(wc -c <"$jpg") / 1024))
  else
    failed=$((failed + 1))
  fi
done

avg=0
[ "$rendered" -gt 0 ] && avg=$((total_kb / rendered))
echo "og-images — ${rendered} rendered (~${avg} kb avg), ${up_to_date} up-to-date, ${failed} failed (chrome+ffmpeg, no python)"
exit 0
