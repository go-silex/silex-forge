# Cloudflare Pages — projet `silex-forge`

## Cible

| Champ | Valeur |
|---|---|
| Projet Pages | `silex-forge` |
| Compte | Tool@gosilex.com (Gosilex) |
| Mode | **Direct Upload** + **GitHub Action** (deploy `site/`) |
| Domaine custom | `forge.gosilex.com` → CNAME `silex-forge-6mm.pages.dev` (proxied) |
| Production | branch `main` côté wrangler |

### Pourquoi pas Git Integration ici

`silex-demos` est en **Git Integration** (idéal).  
Ce projet a été recréé en **Direct Upload** (API `pages/projects`) — le mode est **irréversible**.  
On compense avec :

1. **Git = source de vérité** (`site/` + `registry/` dans le repo)
2. **`.github/workflows/deploy-pages.yml`** → `wrangler pages deploy site` sur push `main` (paths `site/**`)
3. Token CF **uniquement** dans secrets GH org/repo — **pas** sur les postes

Secrets GH requis (org `go-silex` ou repo) :

| Secret | Valeur |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Token avec *Pages Edit* + *Account read* |
| `CLOUDFLARE_ACCOUNT_ID` | `YOUR_CLOUDFLARE_ACCOUNT_ID` |

## Checklist ops (fait / à faire)

- [x] Repo `go-silex/silex-forge`
- [x] Projet Pages `silex-forge` + premier deploy
- [x] Domaine `forge.gosilex.com`
- [ ] Secrets GH `CLOUDFLARE_*` pour le workflow auto
- [ ] Cloudflare Access — [`cloudflare-access.md`](./cloudflare-access.md)

## Publish flow (équipe)

```bash
# 1) publish.sh → commit + push site/ + registry/
plugins/silex-forge/scripts/publish.sh mon-slug ./file.html --title "…"
# 2) GH Action déploie site/ → forge.gosilex.com
```

Fallback manuel (ops avec CF credentials) :

```bash
npx wrangler pages deploy site --project-name=silex-forge --branch=main
```

## Migration depuis `~/.roxabi/silex-forge`

Ancien : Direct Upload local ad-hoc.  
Nouveau : repo + `/a/` + catalogue généré.

| Ancien | Nouveau |
|---|---|
| `/silex-talk-mcp/` | `/a/silex-talk-mcp/` (301 via `_redirects`) |
| — | `/a/github-claude-ops/` |
