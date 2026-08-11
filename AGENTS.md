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

- **SSOT** : hub `$artifacts_dir/<slug>/` (path local via forge.config)
- `/a/<slug>/` — deploy live Access, catalogue
- `/s/<slug>/<key>/` — share public unlisted (Bypass Access)
- `registry/` — jamais servi

## Deploy

Push `main` → GH Action Pages. Token BW : `cloudflare/silex-forge-pages-deploy`.
