#!/usr/bin/env python3
"""gen-og-images.py — screenshot each forge artifact into site/a/<slug>/og.png

Mirrors roxabi-forge gen-og-images (Playwright/Chromium), adapted to silex layout:
  registry/*.json  →  site/a/<slug>/index.html  →  site/a/<slug>/og.png

Usage (repo root or any cwd):
  python3 plugins/silex-forge/scripts/gen-og-images.py
  python3 plugins/silex-forge/scripts/gen-og-images.py --slug passation-2026-07
  python3 plugins/silex-forge/scripts/gen-og-images.py --force

Idempotent: re-renders only if PNG missing or older than index.html (--force = all).
Graceful: if Chromium/playwright missing → exit 0 + warning (publish still works).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REG = ROOT / "registry"
SITE = ROOT / "site"

VIEWPORT = {"width": 1200, "height": 630}
# Decks are often 16:9 fullscreen — capture a bit taller hero then we still
# use 1200×630 OG viewport (social card crop of top of page).


def load_targets(slug_filter: str | None) -> list[tuple[str, Path, Path]]:
    """Return list of (slug, html_path, og_path)."""
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
        if data.get("list_on_index", True) is False and not slug_filter:
            # still allow --slug force for unlisted
            pass
        rel = str(data.get("path") or f"/a/{slug}/").lstrip("/").rstrip("/")
        html = SITE / rel / "index.html"
        if not html.is_file() and (SITE / "a" / slug / "index.html").is_file():
            html = SITE / "a" / slug / "index.html"
        if not html.is_file():
            print(f"skip {slug}: no index.html at {html}", file=sys.stderr)
            continue
        og = html.parent / "og.png"
        out.append((slug, html, og))
    return out


def is_stale(html: Path, png: Path) -> bool:
    if not png.exists():
        return True
    return png.stat().st_mtime < html.stat().st_mtime


def main() -> int:
    ap = argparse.ArgumentParser(description="Render per-artifact OG preview images.")
    ap.add_argument("--slug", default="", help="Only this slug")
    ap.add_argument("--force", action="store_true", help="Re-render even if up-to-date")
    ap.add_argument(
        "--timeout",
        type=int,
        default=45000,
        help="page.goto timeout ms (default 45000)",
    )
    args = ap.parse_args()

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

    # prune orphan og.png under site/a/* that have no registry entry
    known_dirs = {html.parent.resolve() for _, html, _ in targets}
    pruned = 0
    a_root = SITE / "a"
    if a_root.is_dir():
        for png in a_root.glob("*/og.png"):
            if png.parent.resolve() not in known_dirs:
                # only prune if no index.html either
                if not (png.parent / "index.html").is_file():
                    png.unlink(missing_ok=True)
                    pruned += 1

    if not worklist:
        print(
            f"og-images — 0 rendered, {up_to_date} up-to-date, 0 failed, {pruned} pruned"
        )
        return 0

    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "⚠ playwright not installed — skip OG images "
            "(pip/uv: playwright + playwright install chromium)",
            file=sys.stderr,
        )
        return 0

    rendered = 0
    failed = 0

    with sync_playwright() as pw:
        try:
            browser = pw.chromium.launch()
        except Exception as e:
            print(
                f"⚠ chromium launch failed ({e}) — skip OG images",
                file=sys.stderr,
            )
            return 0

        # dpr=1 keeps thumbs ~200–400KB (dpr=2 was multi‑MB for image-heavy decks)
        context = browser.new_context(
            viewport=VIEWPORT,
            device_scale_factor=1,
        )
        page = context.new_page()

        for slug, html, og in worklist:
            tmp = og.parent / "og.tmp.png"
            try:
                url = html.resolve().as_uri()
                page.goto(url, wait_until="networkidle", timeout=args.timeout)
                # fonts + reveal animations
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
                      // hide forge share bar if injected
                      document.querySelectorAll('[data-forge-share-bar]').forEach(el => {
                        el.style.display = 'none';
                      });
                    }"""
                )
                page.wait_for_timeout(500)
                page.screenshot(path=str(tmp), full_page=False)
                os.replace(tmp, og)
                rendered += 1
                print(f"  ✓ {slug} → {og.relative_to(ROOT)}")
            except Exception as e:
                print(f"  ⚠ {slug}: {e}", file=sys.stderr)
                tmp.unlink(missing_ok=True)
                failed += 1

        browser.close()

    print(
        f"og-images — {rendered} rendered, {up_to_date} up-to-date, "
        f"{failed} failed, {pruned} pruned"
    )
    return 0 if failed == 0 or rendered > 0 else 0  # never fail publish hard


if __name__ == "__main__":
    raise SystemExit(main())
