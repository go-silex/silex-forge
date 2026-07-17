---
name: forge-publish
description: >-
  Publie un artefact HTML sur forge.gosilex.com (interne Cloudflare Access ;
  share optionnel via /s/<slug>/<key>/). Triggers: "publish forge", "forge publish",
  "mettre sur forge", "forge.gosilex.com", "publier le deck", "artefact forge".
---

# forge-publish — publier sur forge.gosilex.com

Publie un **HTML autonome** (ou un dossier avec `index.html`) sur le host d’artefacts internes Silex.

| | |
|---|---|
| Host | `https://forge.gosilex.com` |
| Défaut | `/a/<slug>/` — **Cloudflare Access** (équipe) |
| Share | `/s/<slug>/<key>/` — Bypass Access, **clé**, non listé |
| Mécanique | git push sur `go-silex/silex-forge` → CF Pages |

**≠** `demo.gosilex.com` (démos client). **≠** Vercel.  
**Pas de `/p/`** — purgé ; utiliser `--share` / barre **Externe**.

## Usage

```bash
# Depuis le clone du repo silex-forge, ou via chemin plugin :
S="${CLAUDE_PLUGIN_ROOT}/scripts/publish.sh"
# si skill installé depuis marketplace in-repo :
# S=plugins/silex-forge/scripts/publish.sh

# Interne
"$S" <slug> <fichier.html|dossier> --title "…" --type deck

# Interne + mint share
"$S" <slug> <fichier.html|dossier> --share --title "…" --type deck
```

Types utiles : `deck` · `talk` · `guide` · `diagram` · `gallery` · `html`.

Autres :

```bash
"$S" --share <slug>
"$S" --unshare <slug>
"$S" --list
"$S" --remove <slug>
"$S" --rebuild-index
```

## Règles

1. **Slug** kebab : `^[a-z0-9]+(-[a-z0-9]+)*$`
2. HTML **self-contained** (images en data-URI) — surtout pour les liens share
3. **Ne pas** publier de secrets / données clients en clair
4. Share = secret dans l’URL — ne pas coller la clé dans le catalogue / Slack public
5. Préférer **interne** pour formations équipe (ex. decks Pierre/Arman)

## Après publish

- URL équipe : `https://forge.gosilex.com/a/<slug>/`
- Share : barre **Externe** sur la page, ou `publish.sh --share <slug>`
- Index catalogue (Access) : `https://forge.gosilex.com/`
- Access : voir `docs/cloudflare-access.md` du repo

## Env

| Var | Défaut |
|---|---|
| `FORGE_REPO` | `git@github.com:go-silex/silex-forge.git` |
| `PUBLIC_HOST` | `forge.gosilex.com` |
