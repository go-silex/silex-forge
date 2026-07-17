# silex-forge — agent context

| | |
|---|---|
| **URL** | https://forge.gosilex.com |
| **Job** | Host artefacts HTML **internes** (Access) + opt-in public `/p/` |
| **≠** | `demo.gosilex.com` (clients) · `share.gosilex.com` (produit ACL) · Vercel |
| **Publish** | `plugins/silex-forge/scripts/publish.sh` |
| **Index** | `plugins/silex-forge/scripts/gen-index.py` ← `registry/*.json` |

## Paths

- Interne : `site/a/<slug>/`
- Public : `site/p/<slug>/`
- Ne jamais servir `registry/` (hors `site/`)

## Deploy

Git push `main` → CF Pages output `site`. Voir `docs/cloudflare-pages.md` + `docs/cloudflare-access.md`.
