#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# silex-cheatsheet · rendu d'une infographie poster
#
#   render.sh <fiche.html> --measure            → hauteur naturelle du contenu
#   render.sh <fiche.html> <sortie.png> [H]     → export ×2 + JPG + aperçu fil
#
# Largeur canvas toujours 1260. La hauteur se mesure, elle ne se choisit pas.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

WIDTH=1260
SRC="${1:?usage: render.sh <fiche.html> [--measure | <sortie.png> [hauteur]]}"
[ -f "$SRC" ] || { echo "introuvable : $SRC" >&2; exit 1; }
SRC="$(cd "$(dirname "$SRC")" && pwd)/$(basename "$SRC")"

# ── trouver un Chrome utilisable ─────────────────────────────────────────────
CHROME=""
for c in \
  "$HOME"/.cache/puppeteer/chrome/*/chrome-mac-arm64/"Google Chrome for Testing.app"/Contents/MacOS/"Google Chrome for Testing" \
  "$HOME"/.cache/puppeteer/chrome/*/chrome-linux64/chrome \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
  "$(command -v google-chrome || true)" \
  "$(command -v chromium || true)"
do
  [ -n "$c" ] && [ -x "$c" ] && CHROME="$c" && break
done
[ -n "$CHROME" ] || { echo "aucun Chrome trouvé (installe-le ou lance: npx puppeteer browsers install chrome)" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

shot() { # shot <scale> <winW> <winH> <out>
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --force-device-scale-factor="$1" --virtual-time-budget=8000 \
    --window-size="$2","$3" --screenshot="$4" "file://$SRC" 2>/dev/null || true
  [ -s "$4" ] || { echo "le rendu a échoué" >&2; exit 1; }
}

# ── mode mesure ──────────────────────────────────────────────────────────────
if [ "${2:-}" = "--measure" ]; then
  MEAS="$TMP/measure.html"
  # canvas en hauteur libre, sans rognage
  python3 - "$SRC" "$MEAS" <<'PY'
import re, sys
src, out = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
s = re.sub(r'(\.canvas\{[^}]*?)height:\s*[0-9]+px;', r'\1height:auto;', s, count=1, flags=re.S)
s = re.sub(r'(\.canvas\{[^}]*?)overflow:hidden;', r'\1', s, count=1, flags=re.S)
# l'ombre portée du canvas déborde de ~90px : elle fausserait la mesure
s = s.replace("</style>", ".canvas{box-shadow:none !important}\n</style>")
open(out, "w", encoding="utf-8").write(s)
PY
  SRC_BAK="$SRC"; SRC="$MEAS"
  shot 1 $((WIDTH + 80)) 4000 "$TMP/m.png"
  SRC="$SRC_BAK"
  python3 - "$TMP/m.png" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
bg = im.getpixel((5, h - 5))                    # fond hors-scène
last = h
for y in range(h - 1, 0, -1):
    row = im.crop((0, y, w, y + 1)).getcolors(maxcolors=8192)
    if not (row and len(row) == 1 and row[0][1] == bg):
        last = y + 1
        break
height = last - 40                              # le body a padding:40px 0 — À RETRANCHER
print(f"hauteur du contenu : {height} px")
print(f"ratio obtenu       : {round(1260/height, 3)}   (confort visé ~0,65)")
print(f"→ mettre height:{height}px dans .canvas, puis relancer sans --measure")
PY
  exit 0
fi

# ── mode export ──────────────────────────────────────────────────────────────
OUT="${2:?usage: render.sh <fiche.html> <sortie.png> [hauteur]}"
HEIGHT="${3:-}"
if [ -z "$HEIGHT" ]; then
  HEIGHT="$(grep -oE 'width:1260px;height:[0-9]+px' "$SRC" | grep -oE '[0-9]+px$' | tr -d 'px' | head -1 || true)"
fi
[ -n "$HEIGHT" ] || { echo "hauteur introuvable : passe-la en 3e argument, ou lance --measure" >&2; exit 1; }

shot 2 $((WIDTH + 80)) $((HEIGHT + 120)) "$TMP/full.png"

python3 - "$TMP/full.png" "$OUT" "$WIDTH" "$HEIGHT" <<'PY'
import sys, os
from PIL import Image
raw, out, W, H = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = Image.open(raw).convert("RGB")
x = ((W + 80) - W) // 2 * 2                     # canvas centré dans la fenêtre
im = im.crop((x, 80, x + W * 2, 80 + H * 2))    # 80 = padding body ×2
im.save(out, optimize=True)
base = os.path.splitext(out)[0]
im.save(base + ".jpg", quality=93, subsampling=1)
im.resize((504, round(504 * H / W)), Image.LANCZOS).save(base + "_feed.jpg", quality=90)

# garde-fou : reste-t-il du vide sous le dernier contenu ?
w, h = im.size
last = 0
for y in range(h - 1, 0, -1):
    if min(im.crop((0, y, w, y + 1)).convert("L").getdata()) < 90:
        last = y
        break
gap = (h - last) // 2
print(f"{out}  {im.size[0]}×{im.size[1]} px  ·  ratio {round(im.size[0]/im.size[1], 3)}")
print(f"JPG : {base}.jpg  ·  aperçu fil LinkedIn : {base}_feed.jpg")
if gap > 60:
    print(f"⚠  {gap} px de vide sous le dernier contenu — relance --measure et corrige la hauteur")
PY
