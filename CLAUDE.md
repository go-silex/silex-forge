# CLAUDE.md — silex-forge

> Chim de `AGENTS.md` + runbook agent. Lire ce fichier en premier dans ce repo.

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

Deploy : push `main` → GitHub Action `Deploy Pages` (secrets CF dans GH + note BW `cloudflare/silex-forge-pages-deploy`).

## Structure

```
site/a/<slug>/        # interne (Access)
# /s/*                 # Function + KV (pas de copie statique sous site/s)
registry/<slug>.json  # métadonnées (jamais servi)
plugins/silex-forge/  # publish + index
plugins/silex-craft/  # silex-slides, frontend-slides, rocky-animation
```

## Plugins dans ce repo

| Plugin | Contenu | Ancien emplacement |
|---|---|---|
| `silex-forge` | `forge-publish` | — |
| `silex-craft` | `silex-slides`, `frontend-slides`, `rocky-animation` | `go-silex/silex-plugins` |

Install :

```
/plugin marketplace add go-silex/silex-forge
/plugin install silex-forge@silex-forge
/plugin install silex-craft@silex-forge
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

## Règles agent

1. Ne **jamais** déployer forge sur Vercel
2. Ne **pas** mettre de secrets dans `site/`
3. Ne **pas** lister les share keys dans le catalogue
4. Publish = git only ; CF token uniquement GH Actions / BW ops
5. Après gros publish : vérifier Access (302 sans cookie) et share (200 sans cookie sur `/s/.../key/`)
