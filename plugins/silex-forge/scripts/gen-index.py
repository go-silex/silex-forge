#!/usr/bin/env python3
"""gen-index.py — génère site/index.html depuis registry/*.json

Les artefacts « public » ont aussi une carte marquée PUBLIC (le chemin /p/…).
Le catalogue lui-même reste derrière Cloudflare Access (racine = interne).
"""
from __future__ import annotations

import json
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]  # repo root
REG = ROOT / "registry"
OUT = ROOT / "site" / "index.html"

TYPE_LABEL = {
    "talk": "Talk",
    "deck": "Deck",
    "guide": "Guide",
    "diagram": "Diagramme",
    "gallery": "Galerie",
    "html": "HTML",
    "other": "Artefact",
}


def load_items() -> list[dict]:
    items = []
    if not REG.is_dir():
        return items
    for p in sorted(REG.glob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"skip {p.name}: {e}", file=sys.stderr)
            continue
        if not data.get("slug") or not data.get("title"):
            print(f"skip {p.name}: slug/title required", file=sys.stderr)
            continue
        # Catalogue: only list_on_index (default True). Share-only links stay hidden.
        if data.get("list_on_index", True) is False:
            continue
        data.setdefault("type", "html")
        data.setdefault("description", "")
        data.setdefault("date", "")
        data["path"] = data.get("path") or f"/a/{data['slug']}/"
        data["shared"] = bool(data.get("share_key") or data.get("share_url"))
        items.append(data)
    # newest first by date string
    items.sort(key=lambda x: x.get("date") or "", reverse=True)
    return items


def card(item: dict) -> str:
    pill_vis = '<span class="pill muted">Interne · Access</span>'
    if item.get("shared"):
        pill_vis += ' <span class="pill public">Share actif</span>'
    tlabel = TYPE_LABEL.get(item["type"], item["type"].title())
    date_s = str(item.get("date") or "")
    date_pill = f'<span class="pill muted">{_esc(date_s)}</span>' if date_s else ""
    desc = _esc(str(item.get("description") or ""))
    title = _esc(str(item["title"]))
    href = _esc(str(item["path"]))
    return f"""
    <a class="card" href="{href}">
      <div class="card-accent" aria-hidden="true"></div>
      <div class="card-body">
        <div class="card-meta">
          <span class="pill">{_esc(tlabel)}</span>
          {pill_vis}
          {date_pill}
        </div>
        <div class="card-title">{title}</div>
        <p class="card-desc">{desc}</p>
        <div class="card-cta">Ouvrir <span aria-hidden="true">→</span></div>
      </div>
    </a>"""


def _esc(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def render(items: list[dict]) -> str:
    cards = "\n".join(card(i) for i in items) if items else """
    <div class="empty">
      <p>Aucun artefact publié pour l’instant.</p>
      <p class="empty-hint">Utilise <code>forge-publish</code> pour pousser un HTML sur <code>/a/&lt;slug&gt;/</code>.</p>
    </div>"""
    n_shared = sum(1 for i in items if i.get("shared"))
    n_int = len(items)
    today = date.today().isoformat()
    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Silex Forge — artefacts internes</title>
<meta name="description" content="Host d'artefacts HTML Silex (interne). Cloudflare Access par défaut ; chemins /p/ optionnellement publics.">
<meta name="robots" content="noindex, nofollow, noarchive">
<meta name="theme-color" content="#031635">
<link rel="icon" type="image/png" href="/images/favicon.png">
<meta property="og:type" content="website">
<meta property="og:url" content="https://forge.gosilex.com/">
<meta property="og:title" content="Silex Forge">
<meta property="og:description" content="Artefacts HTML d'équipe — decks, talks, guides.">
<meta property="og:site_name" content="Silex">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Manrope:wght@400;500;600;700&family=JetBrains+Mono:wght@400&display=swap" rel="stylesheet">
<style>
:root {{
  --paper: #FEFEFE; --paper-deep: #EEF2F7; --mist: #DCE7F2;
  --sky: #6B9FD4; --sky-soft: #A8C2D8; --haze: #D4E4EF;
  --peach: #EB7457; --peach-soft: #F2B49A;
  --secondary: #2e5f9d; --ink: #031635; --ink-soft: #1a2b4b; --outline: #6b7a90;
  --font-display: "Instrument Serif", Georgia, serif;
  --font-body: "Manrope", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, monospace;
}}
*, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
html {{ -webkit-font-smoothing: antialiased; }}
body {{
  min-height: 100vh; font-family: var(--font-body); color: var(--ink);
  background:
    radial-gradient(56% 52% at 78% 18%, rgba(107,159,212,.38) 0%, rgba(107,159,212,.18) 36%, transparent 72%),
    radial-gradient(48% 46% at 12% 88%, rgba(235,116,87,.16) 0%, rgba(168,194,216,.12) 40%, transparent 76%),
    linear-gradient(165deg, #f7f9fc 0%, var(--paper) 45%, var(--paper-deep) 100%);
  position: relative;
}}
body::before {{
  content: ""; position: fixed; inset: 0; pointer-events: none; opacity: .12;
  mix-blend-mode: soft-light; z-index: 0;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
}}
.wrap {{ position: relative; z-index: 1; max-width: 760px; margin: 0 auto; padding: 28px 22px 72px; }}
nav {{ display: flex; align-items: center; justify-content: space-between; margin-bottom: 48px; }}
.logo {{ font-weight: 700; font-size: 1.15rem; letter-spacing: -0.03em; color: var(--ink); text-decoration: none; }}
.nav-meta {{ font-family: var(--font-mono); font-size: .72rem; letter-spacing: .04em; color: var(--outline); }}
.badge {{
  display: inline-flex; align-items: center; gap: 8px; font-size: .68rem; font-weight: 600;
  letter-spacing: .08em; text-transform: uppercase; color: var(--secondary);
  background: rgba(107,159,212,.14); border: 1px solid rgba(107,159,212,.28);
  border-radius: 999px; padding: 6px 12px; margin-bottom: 16px;
}}
.badge-dot {{
  width: 7px; height: 7px; border-radius: 50%; background: var(--peach);
  box-shadow: 0 0 0 3px rgba(235,116,87,.22);
}}
h1 {{
  font-family: var(--font-display); font-weight: 400;
  font-size: clamp(2.2rem, 5vw, 3rem); line-height: 1.1; letter-spacing: -0.02em;
  margin-bottom: 12px;
}}
h1 em {{ font-style: italic; color: var(--secondary); }}
.lede {{
  font-size: 1.05rem; line-height: 1.55; color: var(--ink-soft);
  max-width: 36rem; margin-bottom: 28px;
}}
.lede strong {{ color: var(--ink); font-weight: 600; }}
.stats {{
  display: flex; flex-wrap: wrap; gap: 10px 18px; margin-bottom: 36px;
  font-family: var(--font-mono); font-size: .78rem; color: var(--outline);
}}
.stats b {{ color: var(--ink); font-weight: 500; }}
.section-label {{
  font-size: .68rem; font-weight: 600; letter-spacing: .1em; text-transform: uppercase;
  color: var(--outline); margin-bottom: 14px;
}}
.grid {{ display: grid; gap: 16px; }}
.card {{
  display: block; text-decoration: none; color: inherit;
  background: rgba(255,255,255,.88); backdrop-filter: blur(12px);
  border: 1px solid rgba(3,22,53,.08); border-radius: 0;
  border-top: 1px solid var(--ink);
  box-shadow: none;
  overflow: hidden; transition: border-color .15s, background .15s;
}}
.card:hover {{ background: #fff; border-color: rgba(107,159,212,.45); }}
.card-accent {{ height: 3px; background: linear-gradient(90deg, var(--sky) 0%, var(--peach) 100%); }}
.card-body {{ padding: 20px 22px 18px; display: grid; gap: 10px; }}
.card-meta {{ display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }}
.pill {{
  font-size: .65rem; font-weight: 600; letter-spacing: .04em; text-transform: uppercase;
  padding: 3px 8px; background: rgba(107,159,212,.12); color: var(--secondary);
  border: 1px solid rgba(107,159,212,.22);
}}
.pill.muted {{ background: rgba(3,22,53,.04); color: var(--outline); border-color: rgba(3,22,53,.08); }}
.pill.public {{ background: rgba(235,116,87,.12); color: var(--peach); border-color: rgba(235,116,87,.28); }}
.card-title {{ font-family: var(--font-display); font-size: 1.35rem; line-height: 1.25; }}
.card-desc {{ font-size: .92rem; line-height: 1.5; color: var(--ink-soft); }}
.card-cta {{ font-size: .88rem; font-weight: 600; color: var(--secondary); margin-top: 4px; }}
.card:hover .card-cta {{ color: var(--peach); }}
.note {{
  margin-top: 32px; font-size: .82rem; line-height: 1.55; color: var(--outline); max-width: 36rem;
}}
.note code {{ font-family: var(--font-mono); font-size: .78rem; background: var(--mist); padding: 1px 6px; }}
.note a {{ color: var(--secondary); text-decoration: none; border-bottom: 1px solid rgba(46,95,157,.3); }}
.empty {{
  border-top: 1px solid var(--ink); padding: 28px 8px; color: var(--ink-soft);
}}
.empty-hint {{ margin-top: 8px; font-size: .88rem; }}
.empty code {{ font-family: var(--font-mono); font-size: .8rem; background: var(--mist); padding: 1px 6px; }}
footer {{
  margin-top: 48px; padding-top: 18px; border-top: 1px solid rgba(3,22,53,.08);
  display: flex; flex-wrap: wrap; gap: 10px 18px; justify-content: space-between;
  font-size: .78rem; color: var(--outline);
}}
footer a {{ color: var(--outline); text-decoration: none; }}
footer a:hover {{ color: var(--secondary); }}
</style>
</head>
<body>
  <div class="wrap">
    <nav>
      <a class="logo" href="https://gosilex.com">Silex</a>
      <span class="nav-meta">forge.gosilex.com</span>
    </nav>

    <div class="badge">
      <span class="badge-dot" aria-hidden="true"></span>
      Interne · Cloudflare Access
    </div>

    <h1>Forge <em>Silex</em></h1>
    <p class="lede">
      Host d’artefacts HTML d’équipe — decks, talks, guides.
      <strong>Catalogue = équipe only</strong> (Access).
      Un lien <em>Partager</em> crée une URL à clé sous
      <code style="font-family:var(--font-mono);font-size:.9em;background:var(--mist);padding:1px 6px">/s/…/&lt;key&gt;/</code>
      — publique, <strong>non listée</strong> ici.
    </p>

    <div class="stats">
      <span><b>{n_int}</b> au catalogue</span>
      <span><b>{n_shared}</b> avec share</span>
      <span>index {today}</span>
    </div>

    <p class="section-label">Catalogue</p>
    <div class="grid">
{cards}
    </div>

    <p class="note">
      Publier : skill <code>forge-publish</code> ou
      <code>plugins/silex-forge/scripts/publish.sh</code>.
      Doc Access : <code>docs/cloudflare-access.md</code>.
      Cible long terme : <a href="https://share.gosilex.com">share.gosilex.com</a> (silex-share).
      ≠ démos client (<a href="https://demo.gosilex.com">demo.gosilex.com</a>).
    </p>

    <footer>
      <span>© Silex · forge.gosilex.com</span>
      <a href="https://gosilex.com">gosilex.com</a>
    </footer>
  </div>
</body>
</html>
"""


def main() -> int:
    items = load_items()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(render(items), encoding="utf-8")
    print(f"✓ wrote {OUT.relative_to(ROOT)} ({len(items)} items)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
