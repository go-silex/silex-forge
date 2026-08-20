---
name: forge-setup
description: >-
  Setup / doctor de la config machine silex-forge (hub_root + artifacts dans
  silex-hub). Crée ~/.config/silex/forge.config.json depuis l'example si
  manquant, valide le vault, crée le dossier artefacts. Triggers: "forge setup"
  | "forge doctor" | "setup forge" | "config forge" | "forge config manquante".
---

# forge-setup — config machine silex-forge

Configure le **path local silex-hub** (différent par personne) et le dossier
central d’artefacts. Sans cette config, le hook SessionStart + les skills
publish refusent d’improviser un path.

## Modèle long terme

| Couche | Où | Rôle |
|---|---|---|
| **SSOT artefacts** | `$hub_root/$artifacts_dir/<slug>/` | HTML source dans le vault (Drive/rclone) |
| **Deploy live** | `wrangler pages deploy` | Direct Upload (token `forge.env`) |
| **Config machine** | `~/.config/silex/forge.config.json` | path hub perso (gitignore machine) |
| **Defaults** | plugin `forge.config.example.json` | fallback si pas de local |

Le path `../silex-hub` n’est **pas** portable (Mickael ≠ Pierre ≠ Armand) →
toujours un **absolu** dans la config locale.

## Objectif de sortie

```
✅ ~/.config/silex/forge.config.json (merge depuis example)
✅ hub_root = vault valide (00_COCKPIT + 01_COMPANY)
✅ $hub_root/$artifacts_dir existe
✅ ~/.config/silex/forge.env (token Pages, chmod 600) — requis pour publish
✅ forge-doctor exit 0 (token absent = warning, pas KO hub)
⚠️ plugins craft externes recommandés (diagram-design, huashu-design, frontend-slides)
```

## Étape 0 — Doctor

```bash
S="${CLAUDE_PLUGIN_ROOT}/scripts/forge-doctor.sh"
# in-repo:
# S=plugins/silex-forge/scripts/forge-doctor.sh
bash "$S"
bash "$S" --json   # si besoin machine-readable
```

- **OK** → afficher hub + artifacts. Token + **Étape 6** (plugins craft) quand même si manquants. Stop le reste sauf override demandé.
- **KO** → enchaîner setup (ne pas inventer de path).

## Étape 1 — Résoudre hub_root

Ordre de découverte (proposer, **confirmer** avec l’opérateur) :

1. Fichier existant `~/.config/silex/forge.config.json` → clé `hub_root`
2. `~/.config/silex/hub-root` (config Silex partagée)
3. Cwd / walk-up avec markers `00_COCKPIT` + `01_COMPANY`
4. Chemins fréquents s’ils existent :
   - `$HOME/projects/gosilex/silex-hub`
   - `$HOME/silex-hub`
   - `$HOME/projects/silex-hub`
   - macOS Drive : lister `~/Library/CloudStorage/*/` si besoin
5. Sinon **demander le path absolu** du vault (une question)

Validation **obligatoire** avant écriture :

```bash
HUB="<path absolu>"
test -d "$HUB/00_COCKPIT" && test -d "$HUB/01_COMPANY" && echo "hub OK: $HUB"
```

Si KO → ne pas écrire. Expliquer que le vault est hors repo forge (Drive/rclone).

## Étape 2 — Écrire la config locale

```bash
mkdir -p ~/.config/silex
chmod 700 ~/.config/silex

EXAMPLE="${CLAUDE_PLUGIN_ROOT}/forge.config.example.json"
# in-repo: plugins/silex-forge/forge.config.example.json
LOCAL=~/.config/silex/forge.config.json

python3 - <<PY
import json
from pathlib import Path

example = Path("$EXAMPLE")
local = Path("$LOCAL")
hub = Path("$HUB").expanduser().resolve()

base = json.loads(example.read_text(encoding="utf-8"))
if local.is_file():
    over = json.loads(local.read_text(encoding="utf-8"))
    base.update({k: v for k, v in over.items() if v not in ("", None)})
base["hub_root"] = str(hub)
# garder artifacts_dir de l'example sauf override déjà présent
base.setdefault("artifacts_dir", "00_COCKPIT/Forge/artifacts")
local.write_text(json.dumps(base, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"wrote {local}")
print(f"hub_root={base['hub_root']}")
print(f"artifacts_dir={base['artifacts_dir']}")
PY
```

Ne **jamais** committer `forge.config.json` dans le repo silex-forge.

Optionnel : sync `hub-root` Silex si absent :

```bash
if [ ! -f ~/.config/silex/hub-root ]; then
  echo "$HUB" > ~/.config/silex/hub-root
fi
```

## Étape 3 — Dossier artefacts

```bash
ART="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/lib/load_config.py" --print-artifacts)"
mkdir -p "$ART"
echo "artifacts: $ART"
# README minimal si absent
if [ ! -f "$ART/README.md" ]; then
  cat > "$ART/README.md" <<'EOF'
# Forge artefacts (SSOT)

HTML source par slug : `<slug>/index.html` (+ assets).

- Publish live : skill `forge-publish` → wrangler Pages (pas git)
- Ne pas y mettre de secrets / clés share
- meta optionnelle : `<slug>/meta.json` (title, type, description)
EOF
fi
```

## Étape 4 — Doctor final

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/forge-doctor.sh"
```

Rapport :

```
## forge-setup — rapport

**config**     : ~/.config/silex/forge.config.json
**hub_root**   : [path OK]
**artifacts**  : [path OK | créé]
**doctor**     : ✅|✗

**Suite**
- Générer : `silex-craft@silex-plugins` (`silex-slides` · `silex-onepager` · `silex-cheatsheet`)
  → écrire sous $artifacts/<slug>/
- Publier : forge-publish (hub → wrangler Pages)
- Craft générique (hors charte Silex) : plugins externes ci-dessous
```

## Étape 5 — Token Cloudflare (publish)

Sans token : on peut **écrire** le hub / générer un deck. On ne peut **pas** mettre en live.

Fichier **jamais** dans git / jamais dumpé par doctor :

```
~/.config/silex/forge.env    chmod 600
CLOUDFLARE_ACCOUNT_ID=YOUR_CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_API_TOKEN=…
```

Compte **Gosilex** (`YOUR_CF…`) uniquement — pas `wrangler login` Mickael/Roxabi.

Ordre :

1. Fichier déjà là + doctor `cf token : OK` → skip
2. `bw` dispo → proposer :

```bash
umask 077
mkdir -p ~/.config/silex
{
  echo "CLOUDFLARE_ACCOUNT_ID=YOUR_CLOUDFLARE_ACCOUNT_ID"
  echo "CLOUDFLARE_API_TOKEN=$(bw get notes cloudflare/silex-forge-pages-deploy | tr -d '[:space:]')"
} > ~/.config/silex/forge.env
chmod 600 ~/.config/silex/forge.env
```

3. Sinon **demander le token** (une question) et l’écrire pareil. Ne pas l’écho dans le chat.

Scope : Pages Write + Read, Account Settings Read, Workers KV Storage Edit (pour `--share` CLI).

## Étape 6 — Plugins craft recommandés (externes)

Pas dans `silex-forge` ni `silex-craft`. **Recommander** (scope user) — ne pas bloquer le doctor si absents.

| Repo | Install |
|---|---|
| [diagram-design](https://github.com/cathrynlavery/diagram-design) | marketplace + plugin Claude |
| [huashu-design](https://github.com/alchaincyf/huashu-design) | skill (`npx skills add`) — pas un marketplace Claude |
| [frontend-slides](https://github.com/zarazhangrui/frontend-slides) | marketplace + plugin Claude · **requis** par `silex-slides` |

```text
/plugin marketplace add https://github.com/cathrynlavery/diagram-design
/plugin install diagram-design@diagram-design --scope user

/plugin marketplace add https://github.com/zarazhangrui/frontend-slides
/plugin install frontend-slides@frontend-slides --scope user
```

```bash
npx skills add alchaincyf/huashu-design
# fallback :
# git clone https://github.com/alchaincyf/huashu-design.git ~/.claude/skills/huashu-design
```

CLI équivalent :

```bash
claude plugin marketplace add https://github.com/cathrynlavery/diagram-design
claude plugin install diagram-design@diagram-design --scope user
claude plugin marketplace add https://github.com/zarazhangrui/frontend-slides
claude plugin install frontend-slides@frontend-slides --scope user
npx skills add alchaincyf/huashu-design
```

`silex-slides` (charte Halo) réutilise le moteur `frontend-slides` — sans ce plugin, le wrapper Silex ne peut pas générer.

## Fallback code (rappel)

Tout script forge charge la config ainsi :

1. `FORGE_CONFIG` env (path explicite)
2. `~/.config/silex/forge.config.json`
3. sinon **`forge.config.example.json`** du plugin (defaults, `hub_root` vide → doctor KO)

`hub_root` vide dans le fichier peut encore être bootstrappé depuis
`HUB_ROOT` env ou `~/.config/silex/hub-root`, mais **doctor exige** un vault
valide.

## Style

- FR, tutoiement, une question à la fois
- Ne jamais inventer le path hub d’un collègue
- Pas de secrets dans la config
