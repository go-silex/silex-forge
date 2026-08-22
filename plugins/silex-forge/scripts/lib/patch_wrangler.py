#!/usr/bin/env python3
"""Patch cloned wrangler.toml for deploy (KV id + plain [vars]). Never commit output."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def toml_basic_string(value: str) -> str:
    """Emit a TOML-safe double-quoted string."""
    return json.dumps(value, ensure_ascii=False)


def patch_wrangler(
    path: Path,
    *,
    kv_id: str,
    team_domain: str,
    access_aud: str,
    public_host: str = "",
    shlink_api_url: str = "",
) -> None:
    text = path.read_text(encoding="utf-8")

    needle = 'id = "YOUR_KV_NAMESPACE_ID"'
    if needle in text:
        text = text.replace(needle, f'id = "{kv_id}"')
    elif f'id = "{kv_id}"' not in text:
        text2, n = re.subn(
            r'(binding\s*=\s*"SHARES"\s*\nid\s*=\s*")[^"]*(")',
            rf"\g<1>{kv_id}\2",
            text,
            count=1,
        )
        if n == 0:
            raise SystemExit("could not patch SHARES kv id in wrangler.toml")
        text = text2

    text = re.sub(r"\n\[vars\][\s\S]*?(?=\n\[|\Z)", "\n", text)

    lines = [
        "",
        "[vars]",
        f"CF_ACCESS_TEAM_DOMAIN = {toml_basic_string(team_domain)}",
        f"CF_ACCESS_AUD = {toml_basic_string(access_aud)}",
    ]
    if public_host.strip():
        lines.append(f"PUBLIC_HOST = {toml_basic_string(public_host.strip())}")
    if shlink_api_url.strip():
        lines.append(f"SHLINK_API_URL = {toml_basic_string(shlink_api_url.strip())}")
    lines.append("")

    path.write_text(text.rstrip() + "\n" + "\n".join(lines), encoding="utf-8")


def main() -> int:
    if len(sys.argv) < 5:
        print(
            "usage: patch_wrangler.py <wrangler.toml> <kv_id> <team_domain> <access_aud> "
            "[public_host] [shlink_api_url]",
            file=sys.stderr,
        )
        return 2
    path = Path(sys.argv[1])
    public_host = sys.argv[5] if len(sys.argv) > 5 else ""
    shlink_url = sys.argv[6] if len(sys.argv) > 6 else ""
    patch_wrangler(
        path,
        kv_id=sys.argv[2],
        team_domain=sys.argv[3],
        access_aud=sys.argv[4],
        public_host=public_host,
        shlink_api_url=shlink_url,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
