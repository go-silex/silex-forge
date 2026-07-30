---
name: silex-onepager
description: >-
  One-pager HTML scroll (long-form) pour présenter une roadmap, un cadrage ou
  une proposition client Silex — défilement vertical, narrative métier d'abord,
  liens tickets Spark, déploiement sur forge.gosilex.com. Triggers: "one pager",
  "one-page", "onepager", "page scroll client", "présenter roadmap",
  "forge presentation silex", "long-form client".
  PAS pour les decks 16:9 (utiliser silex-slides).
---

# Silex One-Pager (scroll)

Document **HTML unique**, lecture en **scroll vertical** (pas de slides 16:9).
Idéal pour **valider un plan avec le client** : fil métier → blocs → adéquation
tech → carte tickets → hors-scope.

| | |
|---|---|
| **Format** | Long-form scroll (hero + §01…§N + footer) |
| **VS `silex-slides`** | Slides = pitch/keynote 16:9 ; one-pager = lecture autonome |
| **VS forge-presentation** | Même famille scroll ; ici **defaults Silex client** + Spark + deploy gosilex |

## Quand l’utiliser

- Roadmap / priorisation post-call
- Cadrage de sprint en 1 page partageable
- Synthèse « métier d’abord, tech ensuite » avec liens Pilotage
- Livrable à ouvrir sur **forge.gosilex.com** (Access Silex)

**Ne pas utiliser** pour un deck oral dense → `silex-slides`.

## Phase 0 — Inputs

Collecter (ou déduire) :

1. **Client / projet** (slug forge : ex. `metalyde`)
2. **Titre + date** (YYYY-MM-DD)
3. **Fil conducteur métier** (1 phrase d’ordre de valeur)
4. **Blocs** (3–6) : nom, prio, intérêt métier, adéquation tech, tickets Spark
5. **URL Pilotage** (ex. `https://spark.gosilex.com/metalyde/pilotage`)
6. **Hors-scope** volontaire

Si tickets manquent encore : marquer `Epic NEW · à créer` — ne pas inventer de refs.

## Phase 1 — Structure narrative (obligatoire)

Ordre imposé (métier → tech) :

```
Hero          promesse + pour qui + date
§01 Fil       pourquoi cet ordre de priorité (quotidien → relation → scale)
§02 Vue       cartes des blocs (grid 2×2)
§03…§N        un détail par bloc (métier | tech)
§ Archi       tableau module OS existant → ce qu’on ajoute
§ Tickets     table + liens Pilotage
§ Périmètre   hors-scope + next step
Footer        Metalyde × Silex · date · liens
```

**Règles de prose :**
- Français, ton client (pas jargon interne Silex non expliqué)
- Chaque bloc : **intérêt métier** puis **pourquoi c’est réaliste techniquement**
- Pas de “on va rebuild” si le module existe déjà — dire “enrichir”
- Séparer les canaux (Slack équipe ≠ email client) quand c’est le cas

## Phase 2 — Génération HTML

### Output paths

**SSOT publish = repo `go-silex/silex-forge`** (pas le tree Roxabi).

```
# staging local (tmp ou vault), puis publish.sh
/tmp/{name}.html
# ou miroir vault client :
{silex-hub}/05_PIPELINE/{NN}_{Client}/preparation/{YYYY-MM-DD}_{Name}.html

# après publish (écrit par le script, ne pas hand-edit en prod) :
~/projects/gosilex/silex-forge/site/a/{slug}/index.html
```

`{slug}` : kebab-case ≤ 40 chars (ex. `metalyde-roadmap-performance-blocks`).

### Contraintes fichier

- **Single-file** : CSS + JS inline (sauf fonts Google)
- `data-theme="light"` par défaut (lecture client)
- Nav sticky avec ancres
- Sections `.reveal` + `IntersectionObserver` → `.visible`
- Hero **visible dès le load** (ne pas laisser opacity 0)
- Meta `diagram:*` utiles pour le catalogue (optionnel) :

```html
<!-- diagram-meta:start -->
<meta name="diagram:title" content="…">
<meta name="diagram:date" content="YYYY-MM-DD">
<meta name="diagram:category" content="analysis">
<meta name="diagram:cat-label" content="Roadmap">
<meta name="diagram:color" content="cyan">
<meta name="diagram:badges" content="latest">
<!-- diagram-meta:end -->
```

`publish.sh` injecte les meta OG (`forge-og`) + barre share — ne pas pointer `og:url` vers forge.roxabi.dev.

### Design tokens (Silex light client)

| Token | Valeur |
|---|---|
| Fond | `#f7f8fa` / surfaces `#fff` |
| Ink | `#0b1220` |
| Accent | `#2e5f9d` (interactive blue site) |
| Halo soft | cornflower `rgba(107,159,212,…)` + peach `rgba(235,116,87,…)` en hero |
| Fonts | Outfit (display) + Inter (body) + Space Mono (data) — ou Instrument Serif + Hanken si on veut coller Halo strict |

Réutiliser classes utiles : `.hero`, `.section-h`, `.section-n`, `.kpi-row`, `.panel-wrap`, `.tbl-wrap`, `.caveat-grid`, `.modcard`.

**Référence golden** (pattern métier + tickets, déjà publié) :

```
~/projects/gosilex/silex-forge/site/a/metalyde-roadmap-performance-blocks/index.html
```

### Liens tickets

```html
<a href="https://spark.gosilex.com/{client}/pilotage" target="_blank" rel="noopener">T21 · …</a>
```

- Toujours `rel="noopener"` + `target="_blank`
- Schémas autorisés : `https://`, `#anchor`, chemins relatifs
- Pas de deep-link ticket individuel tant que Spark n’en expose pas — le board suffit

## Phase 3 — Deploy forge.gosilex.com

**Host Silex** = repo **`go-silex/silex-forge`** → Pages `silex-forge` → custom domain **`forge.gosilex.com`** (Access `@gosilex.com`).

**NE PAS** utiliser `~/.roxabi/forge` ni `make -C ~/.roxabi/forge deploy` ni wrangler sur le monolithe Roxabi (`forge.roxabi.dev`).  
Il existe un `Makefile.bak.silex-accident-*` pour rappel : pointer le Makefile Roxabi sur `silex-forge` a déjà cassé le site Silex.

### Publish (seul chemin correct)

```bash
S="${CLAUDE_PLUGIN_ROOT}/scripts/publish.sh"  # ou: plugins/silex-forge/scripts/publish.sh depuis le clone

# Interne (Access, catalogue) — défaut
"$S" {slug} /chemin/vers/onepager.html \
  --title "…" --type guide --desc "…"

# + lien share public unlisted /s/<slug>/<key>/
"$S" {slug} /chemin/vers/onepager.html --share --title "…"
```

Push `main` → GH Action **Deploy Pages** (secret BW `cloudflare/silex-forge-pages-deploy`).

**URL (après Access login) :**

```
https://forge.gosilex.com/a/{slug}/
# ex. golden :
https://forge.gosilex.com/a/metalyde-roadmap-performance-blocks/
```

Voir aussi `~/projects/gosilex/silex-forge/CLAUDE.md` (modèle `/a/` vs `/s/`).

### Pièges deploy

| Erreur | Cause | Fix |
|---|---|---|
| Deploy full `~/.roxabi/forge/_dist` | confondre Roxabi forge et Silex forge | **uniquement** `publish.sh` sur `go-silex/silex-forge` |
| Auth / mauvais compte CF | OAuth wrangler perso / token Roxabi | publish = git only ; CF token = GH Actions |
| 302 Access sur `/a/…` | normal sans cookie | se connecter Cloudflare Access Silex |
| Fichier absent en prod | GH Action pas terminée | `gh run list --repo go-silex/silex-forge` |

## Phase 4 — Livrable à l’utilisateur

Toujours renvoyer :

1. URL `https://forge.gosilex.com/a/{slug}/` (Access)
2. Share URL si `--share` a été demandé
3. Miroir vault / hub si écrit (`00_COCKPIT/Forge/`)
4. Rappel : epics tickets non créés si le one-pager est une **proposition** (pas d’exécution board sans go)

## Anti-patterns

- Slide 16:9 dense “tout sur une page” → utiliser ce skill en **scroll**, pas `silex-slides`
- Fourre-tout “notifications” sans séparer Slack vs email client
- Marquer des tickets “non retenu” dans le texte client sans expliquer “fusionné dans l’epic…”
- **Deploy monolithe Roxabi** (`~/.roxabi/forge/_dist` → `silex-forge` ou `forge`) pour un one-pager Silex
- Écrire sous `~/.roxabi/forge/...` comme SSOT Silex
- Inline d’images lourdes non nécessaires (one-pager = surtout typo + structure)

## Checklist acceptation

- [ ] Scroll fluide, hero lisible au load
- [ ] § numérotés, nav sticky
- [ ] Chaque bloc a métier + tech + tickets
- [ ] Liens Pilotage cliquables
- [ ] Publié via `publish.sh` (repo `go-silex/silex-forge`)
- [ ] GH Action Deploy Pages verte
- [ ] URL `https://forge.gosilex.com/a/{slug}/` communiquée
