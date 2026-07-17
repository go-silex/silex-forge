#!/usr/bin/env python3
"""Inject forge share toolbar into an HTML artifact (internal /a/ view).

Mint is done at click via POST /api/share — only slug is required.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def inject(html: str, slug: str, share_url: str = "", short_url: str = "") -> str:
    cfg = {"slug": slug}
    if share_url:
        cfg["shareUrl"] = share_url
    if short_url:
        cfg["shortUrl"] = short_url
    cfg_js = (
        f"<script>window.__FORGE_SHARE__={json.dumps(cfg, ensure_ascii=False)};</script>"
    )
    bar_js = f"<script>{Path(__file__).with_name('share-bar.js').read_text(encoding='utf-8')}</script>"
    snippet = "\n" + cfg_js + bar_js + "\n"

    # remove previous injection (rough)
    if "__FORGE_SHARE__" in html and "</body>" in html:
        # keep simple: append before body; duplicate bars guarded by __FORGE_SHARE_BAR__
        pass

    if "</body>" in html:
        return html.replace("</body>", snippet + "</body>", 1)
    return html + snippet


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("html_file")
    ap.add_argument("--slug", required=True)
    ap.add_argument("--share-url", default="")
    ap.add_argument("--short-url", default="")
    args = ap.parse_args()
    p = Path(args.html_file)
    p.write_text(
        inject(p.read_text(encoding="utf-8"), args.slug, args.share_url, args.short_url),
        encoding="utf-8",
    )
    print(f"injected share bar → {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
