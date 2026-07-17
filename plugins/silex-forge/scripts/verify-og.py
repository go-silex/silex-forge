#!/usr/bin/env python3
"""Verify OG/SEO meta tags in a local HTML file and/or a live URL."""
from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

REQUIRED = [
    ("title", re.compile(r"<title>\s*([^<]+?)\s*</title>", re.I)),
    ("description", re.compile(r'<meta\s+name=["\']description["\']\s+content=["\']([^"\']+)["\']', re.I)),
    ("og:title", re.compile(r'<meta\s+property=["\']og:title["\']\s+content=["\']([^"\']+)["\']', re.I)),
    ("og:description", re.compile(r'<meta\s+property=["\']og:description["\']\s+content=["\']([^"\']+)["\']', re.I)),
    ("og:url", re.compile(r'<meta\s+property=["\']og:url["\']\s+content=["\']([^"\']+)["\']', re.I)),
]


def check_html(html: str, label: str, expect_title: str = "") -> list[str]:
    errs: list[str] = []
    import html as H
    for name, rx in REQUIRED:
        m = rx.search(html)
        if not m or not m.group(1).strip():
            errs.append(f"{label}: missing {name}")
        else:
            val = H.unescape(m.group(1).strip())
            print(f"  ✓ {name}: {val[:80]}")
            if name == "title" and expect_title and expect_title not in val and H.unescape(expect_title) not in val:
                errs.append(f"{label}: title mismatch (got {val!r})")
    return errs


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "silex-forge-verify-og/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", errors="replace")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", help="local HTML path")
    ap.add_argument("--url", help="live URL (pages.dev preferred — no Access)")
    ap.add_argument("--expect-title", default="")
    args = ap.parse_args()
    if not args.file and not args.url:
        print("need --file and/or --url", file=sys.stderr)
        return 2

    errs: list[str] = []
    if args.file:
        print(f"verify file {args.file}")
        html = Path(args.file).read_text(encoding="utf-8")
        errs.extend(check_html(html, "file", args.expect_title))

    if args.url:
        print(f"verify url {args.url}")
        try:
            html = fetch(args.url)
            errs.extend(check_html(html, "live", args.expect_title))
        except Exception as e:
            errs.append(f"live: fetch failed: {e}")

    if errs:
        for e in errs:
            print(f"  ✗ {e}", file=sys.stderr)
        return 1
    print("verify-og OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
