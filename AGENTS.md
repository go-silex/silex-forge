# silex-forge — agent context

Voir **`CLAUDE.md`** (chim opérationnel complet).

| | |
|---|---|
| **URL** | https://forge.gosilex.com |
| **Job** | Artefacts HTML équipe + share à clé |
| **Publish** | `plugins/silex-forge/scripts/publish.sh` |
| **Config** | `~/.config/silex/forge.config.json` · example + doctor · skill `forge-setup` |
| **Plugin** | `silex-forge@silex-forge` (publish + setup + slides + onepager) · Rocky → `rocky@rocky` |

## Paths

- **SSOT** : hub `$artifacts_dir/<slug>/` (path local via forge.config) — **hors git**
- **main** : engine only (pas `site/a` ni `registry/*.json`)
- **live** : `wrangler pages deploy` (Direct Upload)
- `/a/<slug>/` — live Access · `/s/<slug>/<key>/` — share unlisted

## Deploy

`publish.sh` → build hub → `wrangler pages deploy site`.  
Token : `~/.config/silex/forge.env` (BW `cloudflare/silex-forge-pages-deploy`).  
Compte CF **Gosilex** (`f8026cff…`) — pas l’OAuth Mickael/Roxabi.
