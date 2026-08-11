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
| **Deploy live** | repo `silex-forge` → `site/a/<slug>/` | CF Pages (git push) |
| **Config machine** | `~/.config/silex/forge.config.json` | path hub perso (gitignore machine) |
| **Defaults** | plugin `forge.config.example.json` | fallback si pas de local |

Le path `../silex-hub` n’est **pas** portable (Mickael ≠ Pierre ≠ Armand) →
toujours un **absolu** dans la config locale.

## Objectif de sortie

```
✅ ~/.config/silex/forge.config.json (merge depuis example)
✅ hub_root = vault valide (00_COCKPIT + 01_COMPANY)
✅ $hub_root/$artifacts_dir existe
✅ forge-doctor exit 0
```

## Étape 0 — Doctor

```bash
S="${CLAUDE_PLUGIN_ROOT}/scripts/forge-doctor.sh"
# in-repo:
# S=plugins/silex-forge/scripts/forge-doctor.sh
bash "$S"
bash "$S" --json   # si besoin machine-readable
```

- **OK** → afficher hub + artifacts, stop (rien à faire sauf si l’user veut override).
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

- Publish live : skill `forge-publish` → git `silex-forge` `site/a/<slug>/`
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
- Générer un deck : silex-slides / frontend-slides / silex-onepager
  → écrire sous $artifacts/<slug>/
- Publier : forge-publish (copie hub → site/a + registry + push)
```

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
