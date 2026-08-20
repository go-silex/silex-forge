---
name: forge-publish
description: >-
  Publie un artefact HTML sur forge.gosilex.com (interne Cloudflare Access ;
  share optionnel via /s/<slug>/<key>/). Triggers: "publish forge", "forge publish",
  "mettre sur forge", "forge.gosilex.com", "publier le deck", "artefact forge".
---

# forge-publish — publier sur forge.gosilex.com

Publie un **HTML autonome** (ou un dossier avec `index.html`) sur le host d’artefacts internes Silex.

Générer le HTML = **`silex-craft@silex-plugins`** (`silex-slides` · `silex-onepager` · `silex-cheatsheet`). Ce skill = **upload only**.

| | |
|---|---|
| Host | `https://forge.gosilex.com` |
| Défaut | `/a/<slug>/` — **Cloudflare Access** (équipe) |
| Share | `/s/<slug>/<key>/` — Bypass Access, **clé**, non listé |
| SSOT | **hub** `$artifacts/<slug>/` (path via forge.config locale) |
| Deploy | hub → `wrangler pages deploy` (token `~/.config/silex/forge.env`) |

**≠** `demo.gosilex.com` (démos client). **≠** Vercel.  
**Pas de `/p/`** — purgé ; utiliser `--share` / barre **Externe**.

## Prérequis config

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/forge-doctor.sh"
```

Si **KO** → skill **`forge-setup`** (ne pas inventer `hub_root`).  
Publish exige aussi `~/.config/silex/forge.env` (token Pages Gosilex). Doctor warn si absent.  
Config locale : `~/.config/silex/forge.config.json` (fallback plugin `forge.config.example.json`).

## Usage

```bash
S="${CLAUDE_PLUGIN_ROOT}/scripts/publish.sh"
# in-repo: S=plugins/silex-forge/scripts/publish.sh

# Depuis le hub SSOT (path omis si $artifacts/<slug>/index.html existe)
"$S" <slug> --title "…" --type deck

# Depuis un fichier/dossier (copie aussi vers hub SSOT, puis wrangler)
"$S" <slug> <fichier.html|dossier> --title "…" --type deck

# Interne + mint share
"$S" <slug> [path] --share --title "…" --type deck
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
6. Générer les decks **dans le hub** (`artifacts/<slug>/`) puis publish

## Après publish

- URL équipe : `https://forge.gosilex.com/a/<slug>/`
- Share : barre **Externe** sur la page, ou `publish.sh --share <slug>`
- Index catalogue (Access) : `https://forge.gosilex.com/`
- Hub SSOT mis à jour sous `$artifacts/<slug>/`
- Access : voir `docs/cloudflare-access.md` du repo

## Env / config

| Source | Clés |
|---|---|
| `~/.config/silex/forge.config.json` | `hub_root`, `artifacts_dir`, `public_host`, `pages_project`… |
| `~/.config/silex/forge.env` | `CLOUDFLARE_API_TOKEN` (+ `CLOUDFLARE_ACCOUNT_ID`) |
| Env override | `FORGE_REPO`, `PUBLIC_HOST`, `FORGE_CONFIG`, `FORGE_ENV` |
