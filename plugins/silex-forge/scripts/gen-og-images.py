#!/usr/bin/env python3
"""gen-og-images.py — screenshot each forge artifact into site/a/<slug>/og.jpg

Playwright capture (1200×630) → Pillow JPEG compress (quality 80 by default).
Output is compressed **at generation** (no fat PNG intermediate committed).

  registry/*.json  →  site/a/<slug>/index.html  →  site/a/<slug>/og.jpg

Usage:
  uv run --with playwright --with pillow \\
    python plugins/silex-forge/scripts/gen-og-images.py
  … --slug passation-2026-07 --force
  … --quality 75

Idempotent: re-renders if og.jpg missing/older than index.html.
Graceful: missing playwright/chromium → exit 0 + warn.
"""
from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REG = ROOT / "registry"
SITE = ROOT / "site"

VIEWPORT = {"width": 1200, "height": 630}
OG_NAME = "og.jpg"
LEGACY_PNG = "og.png"
DEFAULT_QUALITY = 80


def load_targets(slug_filter: str | None) -> list[tuple[str, Path, Path]]:
    """Return list of (slug, html_path, og_jpg_path)."""
    out: list[tuple[str, Path, Path]] = []
    if not REG.is_dir():
        return out
    for p in sorted(REG.glob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"skip {p.name}: {e}", file=sys.stderr)
            continue
        slug = data.get("slug")
        if not slug:
            continue
        if slug_filter and slug != slug_filter:
            continue
        rel = str(data.get("path") or f"/a/{slug}/").lstrip("/").rstrip("/")
        html = SITE / rel / "index.html"
        if not html.is_file() and (SITE / "a" / slug / "index.html").is_file():
            html = SITE / "a" / slug / "index.html"
        if not html.is_file():
            print(f"skip {slug}: no index.html at {html}", file=sys.stderr)
            continue
        og = html.parent / OG_NAME
        out.append((slug, html, og))
    return out


def is_stale(html: Path, og: Path) -> bool:
    if not og.exists():
        return True
    return og.stat().st_mtime < html.stat().st_mtime


def compress_screenshot_png(png_bytes: bytes, quality: int) -> bytes:
    """PNG screenshot bytes → optimized progressive JPEG."""
    try:
        from PIL import Image
    except ImportError as e:
        raise RuntimeError(
            "pillow required for JPEG compress (uv run --with pillow …)"
        ) from e

    img = Image.open(io.BytesIO(png_bytes))
    if img.mode in ("RGBA", "LA", "P"):
        bg = Image.new("RGB", img.size, (255, 255, 255))
        if img.mode == "P":
            img = img.convert("RGBA")
        alpha = img.split()[-1] if img.mode in ("RGBA", "LA") else None
        bg.paste(img, mask=alpha)
        img = bg
    elif img.mode != "RGB":
        img = img.convert("RGB")

    # ensure OG card size (playwright viewport is already 1200×630)
    if img.size != (VIEWPORT["width"], VIEWPORT["height"]):
        img = img.resize(
            (VIEWPORT["width"], VIEWPORT["height"]),
            Image.Resampling.LANCZOS,
        )

    buf = io.BytesIO()
    img.save(
        buf,
        format="JPEG",
        quality=quality,
        optimize=True,
        progressive=True,
        subsampling="4:2:0",
    )
    return buf.getvalue()


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Render compressed per-artifact OG preview images (JPEG)."
    )
    ap.add_argument("--slug", default="", help="Only this slug")
    ap.add_argument("--force", action="store_true", help="Re-render even if up-to-date")
    ap.add_argument(
        "--quality",
        type=int,
        default=DEFAULT_QUALITY,
        help=f"JPEG quality 1–95 (default {DEFAULT_QUALITY})",
    )
    ap.add_argument(
        "--timeout",
        type=int,
        default=45000,
        help="page.goto timeout ms (default 45000)",
    )
    args = ap.parse_args()
    quality = max(40, min(95, args.quality))

    targets = load_targets(args.slug or None)
    if not targets:
        print("og-images — 0 targets (registry empty or slug missing)")
        return 0

    worklist = [
        (slug, html, og)
        for slug, html, og in targets
        if args.force or is_stale(html, og)
    ]
    up_to_date = len(targets) - len(worklist)

    known_dirs = {html.parent.resolve() for _, html, _ in targets}
    pruned = 0
    a_root = SITE / "a"
    if a_root.is_dir():
        for pattern in (f"*/{OG_NAME}", f"*/{LEGACY_PNG}"):
            for f in a_root.glob(pattern):
                if f.parent.resolve() not in known_dirs and not (
                    f.parent / "index.html"
                ).is_file():
                    f.unlink(missing_ok=True)
                    pruned += 1

    if not worklist:
        print(
            f"og-images — 0 rendered, {up_to_date} up-to-date, 0 failed, "
            f"{pruned} pruned (q={quality})"
        )
        return 0

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "⚠ playwright not installed — skip OG images "
            "(uv run --with playwright --with pillow …)",
            file=sys.stderr,
        )
        return 0

    try:
        from PIL import Image  # noqa: F401 — fail early
    except ImportError:
        print(
            "⚠ pillow not installed — skip OG images "
            "(uv run --with playwright --with pillow …)",
            file=sys.stderr,
        )
        return 0

    rendered = 0
    failed = 0
    total_bytes = 0

    with sync_playwright() as pw:
        try:
            browser = pw.chromium.launch()
        except Exception as e:
            print(
                f"⚠ chromium launch failed ({e}) — skip OG images",
                file=sys.stderr,
            )
            return 0

        context = browser.new_context(
            viewport=VIEWPORT,
            device_scale_factor=1,
        )
        page = context.new_page()

        for slug, html, og in worklist:
            try:
                url = html.resolve().as_uri()
                page.goto(url, wait_until="networkidle", timeout=args.timeout)
                page.evaluate(
                    "document.fonts ? document.fonts.ready.then(() => true) : true"
                )
                page.evaluate(
                    """() => {
                      document.querySelectorAll(
                        '.reveal,[data-reveal],.slide:first-child,.slide.active'
                      ).forEach(el => {
                        el.classList.add('revealed','in-view','visible','is-visible','active');
                        el.style.opacity = '1';
                        el.style.transform = 'none';
                        el.style.visibility = 'visible';
                      });
                      document.querySelectorAll('[data-forge-share-bar]').forEach(el => {
                        el.style.display = 'none';
                      });
                    }"""
                )
                page.wait_for_timeout(500)
                # capture compressed in-process — no fat PNG left on disk
                png_bytes = page.screenshot(type="png", full_page=False)
                jpg_bytes = compress_screenshot_png(png_bytes, quality)
                tmp = og.with_suffix(".tmp.jpg")
                tmp.write_bytes(jpg_bytes)
                tmp.replace(og)
                # drop legacy fat PNG if present
                (og.parent / LEGACY_PNG).unlink(missing_ok=True)
                rendered += 1
                total_bytes += len(jpg_bytes)
                kb = len(jpg_bytes) // 1024
                print(f"  ✓ {slug} → {og.relative_to(ROOT)} ({kb} kb, q={quality})")
            except Exception as e:
                print(f"  ⚠ {slug}: {e}", file=sys.stderr)
                failed += 1

        browser.close()

    avg = (total_bytes // rendered // 1024) if rendered else 0
    print(
        f"og-images — {rendered} rendered (~{avg} kb avg), {up_to_date} up-to-date, "
        f"{failed} failed, {pruned} pruned"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
