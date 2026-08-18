# silex-forge — agent context

## Mission

**forge.gosilex.com** = host d’artefacts HTML **d’équipe** (decks, talks, guides).

| Host | Job |
|---|---|
| `forge.gosilex.com` | Artefacts internes + liens share à clé |
| `demo.gosilex.com` | Démos **client** (funnel) — autre repo |
| `share.gosilex.com` | Cible produit ACL (silex-share) — pas encore le runtime |
| Vercel | **Interdit** pour ce flux |

## Accès (pourquoi la nav privée voyait tout)

**Avant 2026-07-17** : Access n’était **pas** branché → le site était public.

**Maintenant** :

| Zone | Comportement |
|---|---|
| `/` catalogue + `/a/*` | **Cloudflare Access** — emails `@gosilex.com` (+ mickael@bouly.io) · OTP |
| `/s/*` | **Bypass Access** — liens share publics (clé dans le path) |

Sans cookie Access → **302** vers `gosilex.cloudflareaccess.com`.

## Interne vs share (modèle v3)

**`/p/` purgé** — pas de path public sans clé. Uniquement `/a/` + `/s/`.

### Interne (défaut)

- URL : `https://forge.gosilex.com/a/<slug>/`
- Listé sur la landing (catalogue)
- Protégé Access

### Share (opt-in)

- URL : `https://forge.gosilex.com/s/<slug>/<key>/`
  - `<key>` = secret haute entropie
  - équivalent conceptuel de `?k=` (1page) — clé dans le **path** (Bypass Access sur `/s/`)
- **Pas** listé sur la landing
- Bypass Access → ouvre en navigation privée
- Shortlink auto si `SHLINK_API_KEY` Pages : `s.gosilex.com/f-<slug>`

### UX share (barre sur `/a/<slug>/`)

1. **Interne** → copie `/a/<slug>/` (Access équipe, **pas** de shlink) + toast
2. **Externe** (Access) → `POST /api/share` → clé **KV** → copie shortlink ou `/s/…` + toast
3. Share actif → badge **Partagé** + **Révoquer** (`DELETE /api/share`)
4. **⇧+Externe** = régénère la clé (ancien lien mort)
5. Landing : sync live `GET /api/share` (filtre Interne / Partagé)
6. CLI : `publish.sh --share` / `--unshare`

## Commandes

```bash
S=plugins/silex-forge/scripts/publish.sh

"$S" mon-deck ./deck.html --title "…" --type deck
"$S" mon-deck ./deck.html --share --title "…"     # + lien share
"$S" --share mon-deck                             # mint share seul
"$S" --unshare mon-deck
"$S" --list
"$S" --remove mon-deck
```

Deploy : `publish.sh` → `wrangler pages deploy` (token local `~/.config/silex/forge.env` · note BW `cloudflare/silex-forge-pages-deploy`). HTML **hors git**.

## Structure

```
# main = ENGINE only
plugins/silex-forge/     # publish + slides + onepager + setup
  forge.config.example.json
  hooks/                 # SessionStart → doctor
  scripts/publish.sh · build-site-from-hub.py · forge-doctor.sh
functions/               # Access middleware, /api/share, /s/*
site/                    # skeleton only (404, _headers, …) — PAS les HTML
# /s/* runtime           # Function + KV

# hors git
# hub  $artifacts/<slug>/{index.html,meta.json}  = SSOT
# live = wrangler Direct Upload (pas de branche payload)
```

## Config machine (artefacts dans silex-hub)

**SSOT HTML** = vault silex-hub partagé (path **différent** par personne)  
**Deploy** = `publish.sh` → build from hub → `wrangler pages deploy` (Direct Upload, comme roxabi-forge)  
**main** = engine only (pas de HTML)

| Fichier | Rôle |
|---|---|
| `~/.config/silex/forge.config.json` | local (hub_root) — **hors git** |
| `~/.config/silex/forge.env` | token Pages (chmod 600) — **hors git** |
| plugin `forge.config.example.json` | defaults + fallback si pas de local |

```bash
plugins/silex-forge/scripts/forge-doctor.sh
plugins/silex-forge/scripts/publish.sh --rebuild-index   # hub → wrangler Pages
# setup interactif → skill forge-setup
```

Loader : local → example. Hook SessionStart : config KO → **forge-setup**.

## Plugin dans ce repo

| Plugin | Contenu |
|---|---|
| **`silex-forge`** | `forge-publish` · `forge-setup` · `silex-slides` · `frontend-slides` · `silex-onepager` · `silex-cheatsheet` |

Ancien plugin `silex-craft` **fusionné** ici.  
**Rocky** : `rocky@rocky` (`go-silex/rocky`) — hors de ce repo.

Install (scope **user**) :

```
/plugin marketplace add go-silex/silex-forge
/plugin install silex-forge@silex-forge

# Rocky (illustrations) — autre marketplace
/plugin marketplace add go-silex/rocky
/plugin install rocky@rocky
```

### Ce qui reste dans `silex-plugins`

| Plugin | Pourquoi |
|---|---|
| `silex-ops` | Vault, session, HPFO, onboarding — pas des artefacts HTML |
| `silex-delivery` | ERP, digests, brain-factory, use-cases — delivery client |

## Docs

- `docs/cloudflare-access.md` — Access + Bypass `/s`
- `docs/cloudflare-pages.md` — deploy Pages + secrets
- `docs/share-model.md` — détail share / clé / shortlink
- `docs/artifacts-config.md` — SSOT hub + forge.config locale / example

## Miniatures OG (landing)

```bash
# pure sh: Chrome headless + ffmpeg (pas de Python)
plugins/silex-forge/scripts/gen-og-images.sh
plugins/silex-forge/scripts/gen-og-images.sh --slug mon-slug --force --quality 4
```

Deps : `google-chrome`|`chromium`, `ffmpeg`, `jq`.  
Écrit `site/a/<slug>/og.jpg` (1200×630). Branché dans `publish.sh` + `--rebuild-index`.

## Règles agent

1. Ne **jamais** déployer forge sur Vercel
2. Ne **pas** mettre de secrets dans `site/`
3. Ne **pas** lister les share keys dans le catalogue
4. Publish = hub SSOT + `wrangler pages deploy` ; token CF = `~/.config/silex/forge.env` (compte **Gosilex** `f8026cff…`) — jamais dans git / GH
5. **main** n’accueille **pas** les HTML (`site/a`, `registry/*.json`) — engine only
6. Après gros publish : vérifier Access (302 sans cookie) et share (200 sans cookie sur `/s/.../key/`)
7. **pages.dev** sous Access (+ middleware 403) — ne jamais sonder `*.pages.dev` comme origin ouverte
8. Secrets share = **KV only** — jamais `share_key` dans meta/registry/HTML
9. Config forge absente → **forge-setup** (ne pas inventer hub_root)
10. Artefacts → hub `$artifacts_dir/<slug>/` ; live CF ← Direct Upload (hors git)
