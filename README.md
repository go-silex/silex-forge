# silex-forge

**Host d’artefacts HTML internes** — `https://forge.gosilex.com`

| | |
|---|---|
| **Audience** | Équipe Silex (Access) + liens `/p/` optionnellement publics |
| **≠** | `demo.gosilex.com` (funnel client) · `share.gosilex.com` (produit ACL long terme) |
| **Deploy** | Cloudflare Pages **git-connected** · output `site/` · `git push` = live |
| **Plugin** | `silex-forge` (skill `forge-publish`) |

## Pourquoi ce repo

`forge.gosilex.com` existait en **Direct Upload** ad-hoc (`~/.roxabi/silex-forge`).  
On industrialise sur le **même pattern que `silex-demos`** :

- accumulateur = **repo git** (pas un dossier machine)
- zéro credential Cloudflare sur les postes
- catalogue auto depuis `registry/`
- **Cloudflare Access** par défaut ; opt-out public = préfixe `/p/`

Inspiration structurelle : `roxabi-forge` (skills + host d’artefacts) — sans le monstre OG/runtime M₂.  
Cible produit plus tard : **`silex-share`**.

## Installer le plugin

```text
/plugin marketplace add go-silex/silex-forge
/plugin install silex-forge@silex-forge
```

## Publier

```bash
S=plugins/silex-forge/scripts/publish.sh

# Interne (défaut) → https://forge.gosilex.com/a/<slug>/
"$S" mon-deck ./mon-deck.html --title "Mon deck" --type deck

# Public → https://forge.gosilex.com/p/<slug>/  (bypass Access)
"$S" mon-teaser ./teaser.html --public --title "Teaser" --type html

"$S" --list
"$S" --remove mon-deck
"$S" --rebuild-index
```

Le script : clone jetable → copie sous `site/a|p/<slug>/` → écrit `registry/<slug>.json` → régénère l’index → commit + push.

## Structure

```
.claude-plugin/marketplace.json
plugins/silex-forge/
  skills/forge-publish/SKILL.md
  scripts/publish.sh
  scripts/gen-index.py
registry/<slug>.json          # métadonnées (hors site/ → jamais servi)
site/                         # BUILD OUTPUT Pages
  index.html                  # catalogue (généré)
  404.html                    # structurel
  _headers  _redirects  robots.txt
  images/
  a/<slug>/                   # INTERNE (Access)
  p/<slug>/                   # PUBLIC (Access bypass)
docs/
  cloudflare-access.md
  cloudflare-pages.md
```

## Sécurité

| Zone | Contrôle |
|---|---|
| Catalogue + `/a/*` | Cloudflare Access (emails `@gosilex.com`) |
| `/p/*` | Public volontaire — policy Bypass |
| Repo | privé `go-silex` |
| robots.txt | `Disallow: /` |

Voir [`docs/cloudflare-access.md`](docs/cloudflare-access.md).

## Artefacts seed

| Path | Contenu |
|---|---|
| `/a/silex-talk-mcp/` | Talk MCP / plugins / second cerveau |
| `/a/github-claude-ops/` | Formation GitHub · secrets · branches · Claude |

## Setup CF (ops)

1. Brancher ce repo en **Git integration** Pages → output `site` — [`docs/cloudflare-pages.md`](docs/cloudflare-pages.md)
2. Domaine `forge.gosilex.com`
3. Access + Bypass `/p/` — [`docs/cloudflare-access.md`](docs/cloudflare-access.md)
