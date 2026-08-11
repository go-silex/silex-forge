# silex-forge

**Host d’artefacts HTML d’équipe** — `https://forge.gosilex.com`

Access team + share unlisted `/s/<slug>/<key>/`. Voir `CLAUDE.md`.

| | |
|---|---|
| **Audience** | Équipe Silex (Access) + liens share à clé (unlisted) |
| **≠** | `demo.gosilex.com` (funnel client) · `share.gosilex.com` / `silex-share` (**archived** 2026-07-30 — jamais livré) |
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
**Host d’artefacts équipe = ce repo** (`silex-share` archivé, produit jamais livré).

## Installer le plugin

Scope **user** (sinon skills invisibles hors du projet d’install) :

```text
/plugin marketplace add go-silex/silex-forge
/plugin install silex-forge@silex-forge
```

Skills : `forge-publish` · `forge-setup` · `silex-slides` · `frontend-slides` · `silex-onepager`.  
Illustrations Rocky (autre marketplace) :

```text
/plugin marketplace add go-silex/rocky
/plugin install rocky@rocky
```

## Config machine (une fois / poste)

Le path **silex-hub** diffère (Mickael / Pierre / Armand) → config **locale** :

```bash
# doctor
plugins/silex-forge/scripts/forge-doctor.sh

# ou skill interactif
# → forge-setup
```

| Fichier | Rôle |
|---|---|
| `~/.config/silex/forge.config.json` | hub_root + artifacts_dir (hors git) |
| `plugins/silex-forge/forge.config.example.json` | defaults + fallback code |

**SSOT artefacts** = `$hub_root/00_COCKPIT/Forge/artifacts/<slug>/`  
**Deploy live** = branche git **`cf-deploy`** (build from hub) → GH Action → CF Pages  
**main** = engine only (plugins + functions — **pas** les HTML).

Hook plugin `SessionStart` : si config KO → rappeler `forge-setup`.

## Publier

```bash
S=plugins/silex-forge/scripts/publish.sh

# Depuis hub SSOT (path omis si artifacts/<slug>/ existe)
"$S" mon-deck --title "Mon deck" --type deck

# Depuis un fichier → écrit hub d'abord, puis cf-deploy
"$S" mon-deck ./mon-deck.html --title "Mon deck" --type deck

"$S" --share mon-deck
"$S" --unshare mon-deck
"$S" --list
"$S" --remove mon-deck
"$S" --rebuild-index   # rebuild full site from hub → cf-deploy
```

Le script : hub SSOT → `build-site-from-hub` → force-push **`cf-deploy`** → Action `wrangler pages deploy`.

## Structure

```
.claude-plugin/marketplace.json
plugins/silex-forge/
  forge.config.example.json
  hooks/                      # SessionStart doctor
  skills/
    forge-publish/
    forge-setup/              # setup + doctor config machine
    silex-slides/
    frontend-slides/
    silex-onepager/
  scripts/publish.sh
  scripts/forge-doctor.sh
  scripts/lib/load_config.py
  scripts/gen-index.py
# registry/*.json + site/a/**  →  PAS sur main (cf-deploy only)
site/                         # skeleton engine (404, headers) — pas les HTML
functions/                    # Access + share
docs/
  cloudflare-access.md
  cloudflare-pages.md
  share-model.md
  artifacts-config.md
```

Branche **`cf-deploy`** (force-push par publish) : `site/` complet + `registry/` + `functions/`.

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
