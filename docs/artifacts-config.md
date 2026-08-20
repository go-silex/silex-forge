# Artefacts + config + pipeline CF

## Pourquoi c’était dupliqué (avant)

| Couche | Rôle historique |
|---|---|
| `site/a/` + `registry/` **dans git** (`main` puis `cf-deploy`) | **Transport deploy** : push → GH Action → `wrangler pages deploy` **sans token CF sur les postes** |
| Hub notes | pointeurs markdown seulement |

Repo **public** (engine) + HTML d’équipe dans git = fuite.  
`cf-deploy` est retiré. Transport = Direct Upload, comme `roxabi-forge`.

## Modèle actuel (engine git + HTML hors git)

| Couche | Emplacement | Git ? |
|---|---|---|
| **SSOT HTML + meta** | `$hub_root/$artifacts_dir/<slug>/` | **non** (rclone Drive, partagé équipe) |
| **Engine** | `plugins/`, `functions/`, `wrangler.toml`, skeleton `site/` | **main** |
| **Live** | projet Pages `silex-forge` | **non** — `wrangler pages deploy` |

```
silex-craft (silex-slides / onepager / cheatsheet)
        ↓ write
hub artifacts/<slug>/{index.html, meta.json}
        ↓ forge-publish / publish.sh
build-site-from-hub.py  →  site/a + registry + catalogue  (temp, jamais commit)
        ↓ wrangler pages deploy site
forge.gosilex.com
```

1 Cloudflare Gosilex + 1 hub silex-hub + 1 host `forge.gosilex.com`.  
Publish = doctor OK (hub) + token Pages dans `forge.env`.

## Config machine

```
~/.config/silex/forge.config.json     # hub_root local
~/.config/silex/forge.env             # CLOUDFLARE_API_TOKEN (chmod 600)
plugins/.../forge.config.example.json # defaults + fallback code
```

Doctor : `plugins/silex-forge/scripts/forge-doctor.sh`  
Setup : skill `forge-setup`  
Hook SessionStart : rappel si config KO. Token absent = warning (generate OK, publish KO).

## Commandes

```bash
# rebuild full deploy from hub (tous les slugs)
plugins/silex-forge/scripts/publish.sh --rebuild-index

# publish un slug (écrit hub puis wrangler)
plugins/silex-forge/scripts/publish.sh mon-slug --title "…" --type deck

# list hub
plugins/silex-forge/scripts/publish.sh --list
```

## main ne contient pas

- `site/a/**` (HTML live)
- `site/index.html` (catalogue — généré par `gen-index.py` au publish)
- `registry/*.json`
- aucune branche payload

Garder : `site/404.html`, `_headers`, `_redirects`, `robots.txt`, `images/`, `functions/`.
