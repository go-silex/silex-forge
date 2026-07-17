#!/usr/bin/env python3
"""Inject forge share toolbar + config into an HTML artifact (internal team view)."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def inject(html: str, share_url: str, short_url: str | None, slug: str) -> str:
    cfg = {
        "slug": slug,
        "shareUrl": share_url,
        "shortUrl": short_url or "",
    }
    cfg_js = (
        f"<script>window.__FORGE_SHARE__={json.dumps(cfg, ensure_ascii=False)};</script>"
    )
    bar_path = Path(__file__).with_name("share-bar.js")
    bar_js = f"<script>{bar_path.read_text(encoding='utf-8')}</script>"
    snippet = cfg_js + bar_js

    # strip previous injection
    if "data-forge-share-bar" in html or "__FORGE_SHARE__" in html:
        # naive: remove last script blocks we added is hard; re-publish overwrites file
        pass

    if "</body>" in html:
        return html.replace("</body>", snippet + "\n</body>", 1)
    return html + "\n" + snippet


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("html_file")
    ap.add_argument("--share-url", required=True)
    ap.add_argument("--short-url", default="")
    ap.add_argument("--slug", required=True)
    args = ap.parse_args()
    p = Path(args.html_file)
    html = p.read_text(encoding="utf-8")
    p.write_text(
        inject(html, args.share_url, args.short_url or None, args.slug),
        encoding="utf-8",
    )
    print(f"injected share bar → {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
