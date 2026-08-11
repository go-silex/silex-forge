# Artefacts + config machine

## Décision

| Couche | Emplacement | Portable ? |
|---|---|---|
| **SSOT éditorial** (HTML source) | `silex-hub` → `$artifacts_dir/<slug>/` | path **local** par personne |
| **Deploy live** | repo `silex-forge` → `site/a/<slug>/` | git partagé |
| **Registry / catalogue** | `registry/*.json` + `site/index.html` | git |
| **Share keys** | Cloudflare KV only | jamais git / hub |

Le path vault diffère (Drive, clone, `~/…`) → **config machine**, pas un relative `../silex-hub` hardcodé.

## Fichiers

```
~/.config/silex/forge.config.json     # local (hors git)
plugins/silex-forge/forge.config.example.json  # defaults commités
```

### Résolution (code)

1. `FORGE_CONFIG` env (path explicite)
2. `~/.config/silex/forge.config.json`
3. sinon **example** (fallback) — doctor **KO** tant que pas de local

`hub_root` vide peut encore bootstrap depuis `HUB_ROOT` / `~/.config/silex/hub-root`, mais **doctor exige** un fichier local + vault valide (`00_COCKPIT` + `01_COMPANY`).

### Exemple local

```json
{
  "version": 1,
  "hub_root": "/home/mickael/projects/gosilex/silex-hub",
  "artifacts_dir": "00_COCKPIT/Forge/artifacts",
  "public_host": "forge.gosilex.com",
  "forge_repo": "git@github.com:go-silex/silex-forge.git"
}
```

## Outils

| Cmd / skill | Rôle |
|---|---|
| `scripts/forge-doctor.sh` | exit 0/1 + rapport |
| skill **forge-setup** | crée local, valide hub, mkdir artifacts |
| hook **SessionStart** | injecte rappel si doctor KO |
| `publish.sh` | path optionnel si hub a le slug ; sync hub après push |

## Flux

```
générer HTML (silex-slides / …)
    → écrire $hub/…/artifacts/<slug>/
    → publish.sh <slug>   # ou path explicite
    → git site/a/<slug>/ + registry
    → CF Pages
    → sync hub + note 00_COCKPIT/Forge/<slug>.md
```
