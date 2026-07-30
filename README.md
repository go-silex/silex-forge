# silex-forge

**Host d’artefacts HTML d’équipe** — `https://forge.gosilex.com`

Access team + share unlisted `/s/<slug>/<key>/`. Voir `CLAUDE.md`.

| | |
|---|---|
| **Audience** | Équipe Silex (Access) + liens share à clé (unlisted) |
| **≠** | `demo.gosilex.com` (funnel client) · `share.gosilex.com` (produit ACL long terme) |
| **Deploy** | Cloudflare Pages · `site/` · push git → **GitHub Action** wrangler (Direct Upload) |
| **Plugin** | `silex-forge` — publish + slides + onepager |

## Pourquoi ce repo

`forge.gosilex.com` existait en **Direct Upload** ad-hoc (`~/.roxabi/silex-forge`).  
On industrialise sur le **même pattern que `silex-demos`** :

- accumulateur = **repo git** (pas un dossier machine)
- zéro credential Cloudflare sur les postes
- catalogue auto depuis `registry/`
- **Cloudflare Access** par défaut ; extérieur = **lien `/s/…` à clé** (pas de path `/p/` ouvert)

Inspiration structurelle : `roxabi-forge` (skills + host d’artefacts) — sans le monstre OG/runtime M₂.  
Cible produit plus tard : **`silex-share`**.

## Installer le plugin

Scope **user** (sinon skills invisibles hors du projet d’install) :

```text
/plugin marketplace add go-silex/silex-forge
/plugin install silex-forge@silex-forge
```

Skills : `forge-publish` · `silex-slides` · `frontend-slides` · `silex-onepager`.  
Illustrations Rocky (autre marketplace) :

```text
/plugin marketplace add go-silex/rocky
/plugin install rocky@rocky
```

## Publier

```bash
S=plugins/silex-forge/scripts/publish.sh

# Interne (défaut) → https://forge.gosilex.com/a/<slug>/
"$S" mon-deck ./mon-deck.html --title "Mon deck" --type deck

# + share (lien /s/<slug>/<key>/, unlisted)
"$S" mon-deck ./mon-deck.html --share --title "Mon deck" --type deck

"$S" --share mon-deck
"$S" --unshare mon-deck
"$S" --list
"$S" --remove mon-deck
"$S" --rebuild-index
```

Le script : clone jetable → copie sous `site/a/<slug>/` → écrit `registry/<slug>.json` → régénère l’index → commit + push.

## Structure

```
.claude-plugin/marketplace.json
plugins/silex-forge/
  skills/
    forge-publish/
    silex-slides/
    frontend-slides/
    silex-onepager/
  scripts/publish.sh
  scripts/gen-index.py
registry/<slug>.json          # métadonnées (hors site/ → jamais servi)
site/                         # BUILD OUTPUT Pages
  index.html                  # catalogue (généré)
  404.html                    # structurel
  _headers  _redirects  robots.txt
  images/
  a/<slug>/                   # INTERNE (Access)
  # share servi par Function /s/* + KV (pas de copie statique)
docs/
  cloudflare-access.md
  cloudflare-pages.md
  share-model.md
```

## Sécurité

| Zone | Contrôle |
|---|---|
| Catalogue + `/a/*` | Cloudflare Access (emails `@gosilex.com`) |
| `/s/*` | Bypass Access + **clé path** validée KV |
| Repo | privé `go-silex` |
| robots.txt | `Disallow: /` |

Voir [`docs/cloudflare-access.md`](docs/cloudflare-access.md).

## Artefacts seed

| Path | Contenu |
|---|---|
| `/a/silex-talk-mcp/` | Talk MCP / plugins / second cerveau |
| `/a/github-claude-ops/` | Formation GitHub · secrets · branches · Claude |
| `/a/passation-2026-07/` | Passation fondateurs |

## Setup CF (ops)

1. Brancher ce repo en **Git integration** Pages → output `site` — [`docs/cloudflare-pages.md`](docs/cloudflare-pages.md)
2. Domaine `forge.gosilex.com`
3. Access team + Bypass `/s` — [`docs/cloudflare-access.md`](docs/cloudflare-access.md)
