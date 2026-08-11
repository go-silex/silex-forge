# Artefacts + config + pipeline CF

## Pourquoi c’était dupliqué (avant)

| Couche | Rôle historique |
|---|---|
| `site/a/` + `registry/` **dans git main** | **Transport deploy** : push → GH Action → `wrangler pages deploy` **sans token CF sur les postes** |
| Hub notes | pointeurs markdown seulement |

Direct Upload CF = irréversible → le contenu HTML devait voyager **par git**.  
D’où la double copie hub ⟷ git : l’une pour éditer, l’autre pour déployer.

## Modèle actuel (engine-only main)

| Couche | Emplacement | Git ? |
|---|---|---|
| **SSOT HTML + meta** | `$hub_root/$artifacts_dir/<slug>/` | **non** (rclone Drive) |
| **Engine** | `plugins/`, `functions/`, `wrangler.toml`, skeleton `site/` | **main** |
| **Payload Pages** | `site/` + `registry/` + `functions/` | branche **`cf-deploy`** (force-push) |

```
silex-slides / onepager / …
        ↓ write
hub artifacts/<slug>/{index.html, meta.json}
        ↓ publish.sh
build-site-from-hub.py  →  site/a + registry + catalogue
        ↓ force-push
branch cf-deploy
        ↓ GH Action
wrangler pages deploy site  →  forge.gosilex.com
```

## Config machine

```
~/.config/silex/forge.config.json     # hub_root local
plugins/.../forge.config.example.json # defaults + fallback code
```

Doctor : `plugins/silex-forge/scripts/forge-doctor.sh`  
Setup : skill `forge-setup`  
Hook SessionStart : rappel si config KO.

## Commandes

```bash
# rebuild full deploy from hub (tous les slugs)
plugins/silex-forge/scripts/publish.sh --rebuild-index

# publish un slug (écrit hub puis cf-deploy)
plugins/silex-forge/scripts/publish.sh mon-slug --title "…" --type deck

# list hub
plugins/silex-forge/scripts/publish.sh --list
```

## CI

`.github/workflows/deploy-pages.yml` :

- push **`cf-deploy`** → deploy payload
- push **`main`** (`functions/**`, `wrangler.toml`) → checkout main + overlay `site/` depuis `cf-deploy` → deploy

Secrets GH inchangés : `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

## main ne contient plus

- `site/a/**` (HTML live)
- `registry/*.json`

Garder : `site/404.html`, `_headers`, `_redirects`, `robots.txt`, `images/`, `functions/`.
