# silex-forge

**Host d’artefacts HTML d’équipe** — `https://forge.gosilex.com`

Access team + share unlisted `/s/<slug>/<key>/`. Voir `AGENTS.md`.

| | |
|---|---|
| **Audience** | Équipe Silex (Access) + liens share à clé (unlisted) |
| **≠** | `demo.gosilex.com` (funnel client) · `share.gosilex.com` / `silex-share` (**archived** 2026-07-30 — jamais livré) |
| **Deploy** | Cloudflare Pages · Direct Upload (`wrangler`) depuis le laptop — HTML **hors git** |
| **Plugin** | `silex-forge` — upload Cloudflare only (`forge-publish` · `forge-setup`) |

## Pourquoi ce repo

`forge.gosilex.com` existait en **Direct Upload** ad-hoc (`~/.roxabi/silex-forge`).  
Modèle actuel = **`roxabi-forge`** :

- **git** = engine (plugin, functions, skeleton) — destiné à être public
- **disque partagé** = silex-hub `artifacts/` (SSOT HTML, hors git)
- **live** = `wrangler pages deploy` (token local, compte Gosilex)
- catalogue auto depuis le hub au publish
- **Cloudflare Access** par défaut ; extérieur = **lien `/s/…` à clé** (pas de path `/p/` ouvert)

## Installer le plugin

Scope **user** (sinon skills invisibles hors du projet d’install) :

```text
/plugin marketplace add go-silex/silex-forge
/plugin install silex-forge@silex-forge
```

Skills : `forge-publish` · `forge-setup`.  
Craft Halo / onepager / cheatsheet = **`silex-craft@silex-plugins`**.  
Craft générique (reco **forge-setup**) :

```text
/plugin marketplace add go-silex/silex-plugins
/plugin install silex-craft@silex-plugins

/plugin marketplace add https://github.com/zarazhangrui/frontend-slides
/plugin install frontend-slides@frontend-slides

/plugin marketplace add https://github.com/cathrynlavery/diagram-design
/plugin install diagram-design@diagram-design

npx skills add alchaincyf/huashu-design

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
| `~/.config/silex/forge.env` | token Pages (chmod 600, hors git) |
| `plugins/silex-forge/forge.config.example.json` | defaults + fallback code |

**SSOT artefacts** = `$hub_root/00_COCKPIT/Forge/artifacts/<slug>/`  
**Deploy live** = `wrangler pages deploy` (Direct Upload)  
**main** = engine only (plugins + functions — **pas** les HTML).

Hook plugin `SessionStart` : si config KO → rappeler `forge-setup`.

## Publier

```bash
S=plugins/silex-forge/scripts/publish.sh

# Depuis hub SSOT (path omis si artifacts/<slug>/ existe)
"$S" mon-deck --title "Mon deck" --type deck

# Depuis un fichier → écrit hub d'abord, puis wrangler
"$S" mon-deck ./mon-deck.html --title "Mon deck" --type deck

"$S" --share mon-deck
"$S" --unshare mon-deck
"$S" --list
"$S" --remove mon-deck
"$S" --rebuild-index   # rebuild full site from hub → wrangler Pages
```

Le script : hub SSOT → `build-site-from-hub` → `wrangler pages deploy site`.

## Structure

```
.claude-plugin/marketplace.json
plugins/silex-forge/
  forge.config.example.json
  hooks/                      # SessionStart doctor
  skills/
    forge-publish/
    forge-setup/              # setup + doctor config machine
  scripts/publish.sh
  scripts/forge-doctor.sh
  scripts/lib/load_config.py
  scripts/gen-index.py
# registry/*.json + site/a/**  →  jamais git (hub + wrangler)
site/                         # skeleton engine (404, headers) — pas les HTML
functions/                    # Access + share
docs/
  cloudflare-access.md
  cloudflare-pages.md
  share-model.md
  artifacts-config.md
```

Aucun payload HTML dans git. Live = Direct Upload.

## Sécurité

| Zone | Contrôle |
|---|---|
| Catalogue + `/a/*` | Cloudflare Access (emails `@gosilex.com`) |
| `/s/*` | Bypass Access + **clé path** validée KV |
| Repo | engine (HTML hors git — viser public) |
| robots.txt | `Disallow: /` |

Voir [`docs/cloudflare-access.md`](docs/cloudflare-access.md).

## Artefacts seed

| Path | Contenu |
|---|---|
| `/a/silex-talk-mcp/` | Talk MCP / plugins / second cerveau |
| `/a/github-claude-ops/` | Formation GitHub · secrets · branches · Claude |
| `/a/passation-2026-07/` | Passation fondateurs |

## Setup CF (ops)

1. Projet Pages **Direct Upload** + token local — [`docs/cloudflare-pages.md`](docs/cloudflare-pages.md)
2. Domaine `forge.gosilex.com`
3. Access team + Bypass `/s` — [`docs/cloudflare-access.md`](docs/cloudflare-access.md)
