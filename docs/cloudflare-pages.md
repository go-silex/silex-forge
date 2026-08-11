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

1. **SSOT HTML** = hub silex-hub (`artifacts/`) — **pas** main
2. **Transport deploy** = branche git **`cf-deploy`** (built par `publish.sh` / `build-site-from-hub.py`)
3. **`.github/workflows/deploy-pages.yml`** → `wrangler pages deploy site` sur push `cf-deploy` (et overlay si `main` functions)
4. Token CF **uniquement** dans secrets GH — **pas** sur les postes
5. **main** = engine only (`plugins/`, `functions/`, skeleton `site/`)

Secrets GH (repo `go-silex/silex-forge`) — **déjà posés** :

| Secret | Source |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Token CF `silex-forge-pages-deploy` (Pages Write + Read, Account Settings Read, scope compte GOSILEX) |
| `CLOUDFLARE_ACCOUNT_ID` | `YOUR_CLOUDFLARE_ACCOUNT_ID` |

Vaultwarden (agent vault) : note **`cloudflare/silex-forge-pages-deploy`** (notes = token ; field `CLOUDFLARE_ACCOUNT_ID`).

```bash
source ~/projects/security/vaultwarden/scripts/agent-bw-login.sh
export CLOUDFLARE_API_TOKEN="$(bw get notes cloudflare/silex-forge-pages-deploy | tr -d '[:space:]')"
export CLOUDFLARE_ACCOUNT_ID=YOUR_CLOUDFLARE_ACCOUNT_ID
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
# 1) SSOT hub + build + force-push cf-deploy
plugins/silex-forge/scripts/publish.sh mon-slug ./file.html --title "…"
#    ou rebuild tout depuis hub :
plugins/silex-forge/scripts/publish.sh --rebuild-index

# 2) GH Action (push cf-deploy) → wrangler pages deploy site → forge.gosilex.com
```

Fallback manuel (ops avec CF credentials + hub local) :

```bash
python3 plugins/silex-forge/scripts/build-site-from-hub.py --repo-root .
npx wrangler pages deploy site --project-name=silex-forge --branch=main
```

## Migration depuis `~/.roxabi/silex-forge`

Ancien : Direct Upload local ad-hoc.  
Nouveau : repo + `/a/` + catalogue généré.

| Ancien | Nouveau |
|---|---|
| `/silex-talk-mcp/` | `/a/silex-talk-mcp/` (301 via `_redirects`) |
| — | `/a/github-claude-ops/` |

## Secrets Pages (Functions)

| Var | Type | Rôle |
|---|---|---|
| `SHLINK_API_KEY` | secret | API Shlink `s.gosilex.com` — shortlinks au share |
| `SHLINK_BASE` | plain | `https://s.gosilex.com` |
| KV `SHARES` | binding | clés share (`share:<slug>`) |

Source ops : `~/.config/silex/shlink-api-key`
