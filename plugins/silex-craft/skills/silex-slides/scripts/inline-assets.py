#!/usr/bin/env python3
"""inline-assets.py — Rend un deck Silex 100% autonome.

Remplace chaque reference `assets/<image>` du HTML par l'image embarquee en
base64 (data URI). Plus aucun dossier `assets/` a copier a cote du deck : le
`.html` se suffit a lui-meme (Drive, mail, Vercel, hors-ligne).

Regles de compression (automatiques, via Pillow ; `sips` en secours sur macOS) :
  - .svg                      -> inline tel quel (data:image/svg+xml)
  - fichier < 250 Ko          -> embarque tel quel (logos, marques, icones)
  - grosse image, sans alpha  -> redimensionnee (max-width) + JPEG  (~×6 plus legere)
  - grosse image, avec alpha  -> redimensionnee (max-width), PNG conserve (transparence)
  - .mp4/.webm/.mov (video)   -> laisses en fichier (non embarquables) + avertissement

Resolution des chemins pour chaque `assets/<nom>` :
  1. a cote du HTML  (<dossier-du-deck>/assets/<nom>)   -> images propres au client
  2. sinon dans la source de verite de la marque         -> --assets-dir (defaut: ../assets)

Usage :
  python3 inline-assets.py <deck.html> [--assets-dir DIR] [--max-width 1600] [--quality 80]

Le HTML est reecrit sur place. Une sauvegarde `<deck>.bak.html` est ecrite avant.
"""

import argparse
import base64
import os
import re
import shutil
import subprocess
import sys
import tempfile

SIZE_PASSTHROUGH = 250 * 1024  # en dessous : on embarque sans recompresser
VIDEO_EXT = {".mp4", ".webm", ".mov", ".m4v"}

# capture le chemin a l'interieur de src="...", src='...', url(...), href="..."
REF_RE = re.compile(
    r"""(?:src|href)\s*=\s*['"]([^'"]*assets/[^'"]+)['"]"""
    r"""|url\(\s*['"]?([^'")]*assets/[^'")]+)['"]?\s*\)""",
    re.IGNORECASE,
)


try:
    from PIL import Image
except ImportError:
    Image = None


def sips_int(path, key):
    try:
        out = subprocess.check_output(["sips", "-g", key, path], stderr=subprocess.DEVNULL).decode()
        for line in out.splitlines():
            if key in line:
                return line.split()[-1]
    except Exception:
        return None
    return None


def data_uri(mime, raw_bytes):
    return f"data:{mime};base64," + base64.b64encode(raw_bytes).decode()


def _optimise_pillow(path, max_width, quality, tmpdir):
    """Backend portable (Linux/macOS/Windows). Retourne (bytes, mime, tag)."""
    img = Image.open(path)
    has_alpha = img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info)

    if img.width > max_width:
        ratio = max_width / img.width
        img = img.resize((max_width, round(img.height * ratio)), Image.LANCZOS)

    if has_alpha:
        out = os.path.join(tmpdir, "o.png")
        img.convert("RGBA").save(out, "PNG", optimize=True)
        mime, tag = "image/png", "png"
    else:
        out = os.path.join(tmpdir, "o.jpg")
        img.convert("RGB").save(out, "JPEG", quality=quality, optimize=True, progressive=True)
        mime, tag = "image/jpeg", "jpg"

    with open(out, "rb") as f:
        return f.read(), mime, tag


def _optimise_sips(path, max_width, quality, tmpdir):
    """Backend macOS historique. Retourne (bytes, mime, tag)."""
    has_alpha = (sips_int(path, "hasAlpha") == "yes")
    width = sips_int(path, "pixelWidth")
    resample = []
    if width and width.isdigit() and int(width) > max_width:
        resample = ["--resampleWidth", str(max_width)]

    if has_alpha:
        out = os.path.join(tmpdir, "o.png")
        cmd = ["sips", "-s", "format", "png", *resample, path, "--out", out]
        mime, tag = "image/png", "png"
    else:
        out = os.path.join(tmpdir, "o.jpg")
        cmd = ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(quality), *resample, path, "--out", out]
        mime, tag = "image/jpeg", "jpg"

    subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
    with open(out, "rb") as f:
        return f.read(), mime, tag


def optimise(path, max_width, quality, tmpdir):
    """Pillow d'abord (portable) ; sips en secours ; sinon on embarque brut."""
    if Image is not None:
        return _optimise_pillow(path, max_width, quality, tmpdir)
    if shutil.which("sips"):
        return _optimise_sips(path, max_width, quality, tmpdir)
    return None


def encode_asset(path, max_width, quality, tmpdir):
    """Retourne (data_uri, mime, taille_finale) pour un fichier image."""
    ext = os.path.splitext(path)[1].lower()
    size = os.path.getsize(path)

    if ext == ".svg":
        with open(path, "rb") as f:
            return data_uri("image/svg+xml", f.read()), "svg", size

    if ext in VIDEO_EXT:
        return None  # non embarquable

    # petit fichier -> tel quel (logos, marques, icones : deja legers, on ne touche pas)
    if size < SIZE_PASSTHROUGH:
        mime = "image/png" if ext == ".png" else "image/jpeg"
        with open(path, "rb") as f:
            return data_uri(mime, f.read()), ext.lstrip("."), size

    # grosse image : on optimise avec le backend disponible
    result = optimise(path, max_width, quality, tmpdir)
    if result is None:
        # Aucun backend : on embarque tel quel plutot que d'echouer.
        # Le deck reste autonome, juste plus lourd.
        mime = "image/png" if ext == ".png" else "image/jpeg"
        with open(path, "rb") as f:
            return data_uri(mime, f.read()), ext.lstrip(".") + " brut", size

    raw, mime, tag = result
    return data_uri(mime, raw), tag, len(raw)


def human(n):
    if n < 1024:
        return f"{n} o"
    if n < 1024 * 1024:
        return f"{n/1024:.0f} Ko"
    return f"{n/1024/1024:.1f} Mo"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("html")
    ap.add_argument("--assets-dir", default=None,
                    help="Source de verite des assets de marque (defaut: ../assets a cote du script)")
    ap.add_argument("--max-width", type=int, default=1600)
    ap.add_argument("--quality", type=int, default=80)
    args = ap.parse_args()

    html_path = os.path.abspath(args.html)
    if not os.path.isfile(html_path):
        sys.exit(f"✗ Introuvable : {html_path}")

    html_dir = os.path.dirname(html_path)
    brand_dir = args.assets_dir or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
    brand_dir = os.path.abspath(brand_dir)

    with open(html_path, "r", encoding="utf-8") as f:
        html = f.read()

    refs = set()
    for m in REF_RE.finditer(html):
        refs.add(m.group(1) or m.group(2))
    refs = {r for r in refs if not r.startswith(("http", "data:"))}

    if not refs:
        print("ℹ Aucune reference `assets/…` locale trouvee — rien a embarquer.")
        return

    tmpdir = tempfile.mkdtemp()
    replaced, missing, videos = [], [], []
    total_before = total_after = 0

    for ref in sorted(refs):
        name = ref.split("assets/", 1)[1]              # nom apres assets/
        # 1) a cote du deck (images propres au client) ; 2) source de marque
        candidates = [os.path.join(html_dir, "assets", name), os.path.join(brand_dir, name)]
        src = next((c for c in candidates if os.path.isfile(c)), None)
        if not src:
            missing.append(ref)
            continue

        before = os.path.getsize(src)
        result = encode_asset(src, args.max_width, args.quality, tmpdir)
        if result is None:  # video
            videos.append(ref)
            continue
        uri, tag, after = result
        html = html.replace(ref, uri)
        replaced.append((ref, tag, before, after))
        total_before += before
        total_after += after

    shutil.rmtree(tmpdir, ignore_errors=True)

    backup = os.path.splitext(html_path)[0] + ".bak.html"
    shutil.copy2(html_path, backup)
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"✓ Deck autonome : {os.path.basename(html_path)}")
    for ref, tag, b, a in replaced:
        print(f"   • {ref:<34} {human(b):>8} → {human(a):>8}  ({tag})")
    print(f"   ── images : {human(total_before)} → {human(total_after)} embarquees")
    print(f"   HTML final : {human(os.path.getsize(html_path))}   (sauvegarde : {os.path.basename(backup)})")
    if videos:
        print("⚠ Videos NON embarquees (a garder en fichier a cote du deck) :")
        for v in videos:
            print(f"   • {v}")
    if missing:
        print("⚠ Assets INTROUVABLES (ni a cote du deck, ni dans la marque) :")
        for v in missing:
            print(f"   • {v}")


if __name__ == "__main__":
    main()
