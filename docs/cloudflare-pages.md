# Cloudflare Pages — projet `silex-forge`

## Cible

| Champ | Valeur |
|---|---|
| Projet Pages | `silex-forge` |
| Compte | Tool@gosilex.com (Gosilex) `f8026cffc9463a03e1a6a76af5301861` |
| Mode | **Direct Upload** (`wrangler pages deploy`) — comme `roxabi-forge` |
| Domaine custom | `forge.gosilex.com` → CNAME `silex-forge-6mm.pages.dev` (proxied) |
| Production | branch `main` côté wrangler (label only — pas de git-connect) |

## Pourquoi pas Git Integration / `cf-deploy`

Le repo est destiné à être **public** (engine / plugin). Les HTML d’équipe restent dans **silex-hub** (Drive partagé). Une branche payload dans le même repo = fuite.

Modèle Roxabi :

```
silex-hub / artifacts/<slug>/     SSOT — hors git
        ↓ publish.sh (OG local + build)
temp clone engine (functions + skeleton)
        ↓ wrangler pages deploy site
Pages silex-forge                 live
```

Token CF = **laptop** (`~/.config/silex/forge.env`), pas secrets GH.

`wrangler` depuis le laptop sur le **mauvais compte** (OAuth Mickael / Roxabi) a déjà cassé un deploy — `forge-setup` fige `CLOUDFLARE_ACCOUNT_ID` Gosilex. Doctor warn si host gosilex + autre account.

## Config machine

| Fichier | Rôle |
|---|---|
| `~/.config/silex/forge.config.json` | `hub_root`, `pages_project`, `cloudflare_account_id` |
| `~/.config/silex/forge.env` | `CLOUDFLARE_API_TOKEN` (+ optionnel `CLOUDFLARE_ACCOUNT_ID`) · chmod 600 |

```bash
# ~/.config/silex/forge.env
CLOUDFLARE_ACCOUNT_ID=f8026cffc9463a03e1a6a76af5301861
CLOUDFLARE_API_TOKEN=…
```

Source token : note BW **`cloudflare/silex-forge-pages-deploy`** (notes = token ; field `CLOUDFLARE_ACCOUNT_ID`).

```bash
umask 077
mkdir -p ~/.config/silex
{
  echo "CLOUDFLARE_ACCOUNT_ID=f8026cffc9463a03e1a6a76af5301861"
  echo "CLOUDFLARE_API_TOKEN=$(bw get notes cloudflare/silex-forge-pages-deploy | tr -d '[:space:]')"
} > ~/.config/silex/forge.env
chmod 600 ~/.config/silex/forge.env
```

Scope token : Pages Write + Read, Account Settings Read, **Workers KV Storage Edit** (CLI `--share`). Compte **Gosilex** uniquement.

## Publish flow (équipe)

```bash
# doctor (hub + token)
plugins/silex-forge/scripts/forge-doctor.sh

# 1 artefact (écrit hub puis wrangler)
plugins/silex-forge/scripts/publish.sh mon-slug ./file.html --title "…"

# rebuild catalogue depuis le hub partagé
plugins/silex-forge/scripts/publish.sh --rebuild-index
```

Pas de `git push` HTML. Pas d’Action `Deploy Pages`.

## Secrets Pages (Functions)

| Var | Type | Rôle |
|---|---|---|
| `SHLINK_API_KEY` | secret | API Shlink `s.gosilex.com` — shortlinks au share |
| `SHLINK_BASE` | plain | `https://s.gosilex.com` |
| KV `SHARES` | binding | clés share (`share:<slug>`) |
| `FORGE_SHARE_SECRET` | secret | bypass CLI `/api/share` |

Source ops : `~/.config/silex/shlink-api-key` · BW `silex-forge/FORGE_SHARE_SECRET`.

## Checklist ops

- [x] Repo `go-silex/silex-forge` (engine)
- [x] Projet Pages `silex-forge` + domaine `forge.gosilex.com`
- [x] Cloudflare Access — [`cloudflare-access.md`](./cloudflare-access.md)
- [ ] Token local sur chaque poste qui publie (`forge.env`)
- [ ] Secrets GH `CLOUDFLARE_*` retirés (plus d’Action deploy)
- [ ] Branche `cf-deploy` + historique HTML purgés **avant** repo public

## Migration depuis `~/.roxabi/silex-forge`

Ancien : Direct Upload local ad-hoc.  
Nouveau : même Direct Upload, SSOT = hub partagé, engine = ce repo.

| Ancien | Nouveau |
|---|---|
| `/silex-talk-mcp/` | `/a/silex-talk-mcp/` (301 via `_redirects`) |
| — | `/a/github-claude-ops/` |
