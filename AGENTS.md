# silex-forge — agent context

Voir **`CLAUDE.md`** (chim opérationnel complet).

| | |
|---|---|
| **URL** | https://forge.gosilex.com |
| **Job** | Artefacts HTML équipe + share à clé |
| **Publish** | `plugins/silex-forge/scripts/publish.sh` |
| **Plugins** | `silex-forge` (publish) · `silex-craft` (slides) · Rocky → `rocky@rocky` |

## Paths

- `/a/<slug>/` — interne Access, catalogue
- `/s/<slug>/<key>/` — share public unlisted (Bypass Access)
- `registry/` — jamais servi

## Deploy

Push `main` → GH Action Pages. Token BW : `cloudflare/silex-forge-pages-deploy`.
