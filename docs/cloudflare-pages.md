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

Secrets GH (repo `go-silex/silex-forge`) — **déjà posés** :

| Secret | Source |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Token CF `silex-forge-pages-deploy` (Pages Write + Read, Account Settings Read, scope compte GOSILEX) |
| `CLOUDFLARE_ACCOUNT_ID` | `f8026cffc9463a03e1a6a76af5301861` |

Vaultwarden (agent vault) : note **`cloudflare/silex-forge-pages-deploy`** (notes = token ; field `CLOUDFLARE_ACCOUNT_ID`).

```bash
source ~/projects/security/vaultwarden/scripts/agent-bw-login.sh
export CLOUDFLARE_API_TOKEN="$(bw get notes cloudflare/silex-forge-pages-deploy | tr -d '[:space:]')"
export CLOUDFLARE_ACCOUNT_ID=f8026cffc9463a03e1a6a76af5301861
npx wrangler pages deploy site --project-name=silex-forge --branch=main
```

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
