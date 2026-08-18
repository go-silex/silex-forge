---
name: silex-cheatsheet
description: >-
  Infographie « cheat sheet » Silex pour LinkedIn : poster HTML dense, sections
  numérotées et codées par couleur, badge auteur en haut, CTA prise de rendez-vous,
  export PNG/JPG haute définition. Format ColdIQ re-skinné aux tokens Silex.
  Triggers: "cheat sheet", "cheatsheet", "infographie", "infographie LinkedIn",
  "fiche LinkedIn", "visuel LinkedIn dense", "poster", "carte récap",
  "fais-moi une infographie sur".
  PAS pour un deck 16:9 (utiliser silex-slides), ni pour une page scroll client
  (utiliser silex-onepager).
---

# Silex Cheat Sheet (infographie LinkedIn)

**Image unique**, dense, faite pour être **enregistrée** puis relue. Un sujet, 5 à 8
sections numérotées, une thèse par section. Publiée sur LinkedIn sous le nom d'un
fondateur.

| | |
|---|---|
| **Format** | Poster : largeur **1260 px fixe**, hauteur **variable** selon la densité |
| **Export** | ×2 (PNG + JPG). Ratio cible ~0,65 (référence : les cheat sheets ColdIQ) |
| **VS `silex-slides`** | Slides = oral 16:9 ; cheat sheet = une image qu'on garde |
| **VS `silex-onepager`** | One-pager = page scroll pour un client ; cheat sheet = contenu public |

## Source de vérité : ne rien dupliquer

Cette règle prime sur tout le reste.

| Élément | Où il vit | Le skill… |
|---|---|---|
| Tokens, template, scripts | **Ici, dans le skill** | les utilise tels quels, ne les réinvente pas |
| Contenu métier (offre, stack, chiffres, méthode) | **Vault + gosilex.com** | va les **lire**, ne les recopie **jamais** ici |
| Fiches produites | `$HUB/09_COMMUNICATION/Infographies/` | y écrit ses livrables |
| Photo fondateur + logo | `$HUB/09_COMMUNICATION/Infographies/_assets/` | y pointe en `../_assets/`, une seule copie pour toute la série |

`$HUB` = contenu de `~/.config/silex/hub-root`.

**Si tu es tenté d'écrire un chiffre ou une définition d'offre dans ce fichier : ne le fais pas.**
Prix et périmètre = `gosilex.com` + `01_COMPANY/Silex-Offres-Detail-Packs.md`.

## Phase 0 — Cadrage

Collecter, ou déduire puis faire confirmer :

1. **Le sujet** et l'angle (la thèse défendue, pas le thème)
2. **L'émetteur** (Pierre par défaut)
3. **L'audience** (dirigeants de PME et d'agences par défaut)

Puis **lire avant d'écrire** :

- `$HUB/02_BRAND/Voice_LinkedIn.md` et `Narrative_Lexical_Field.md` (voix, mots interdits)
- `$HUB/02_BRAND/Visual_Brand_Guidelines.md` (charte)
- La matière déjà existante : `$HUB/09_COMMUNICATION/1_Torch/Content/` (posts publiés),
  `$HUB/01_COMPANY/`, notes de call dans `$HUB/05_PIPELINE/*/meeting-notes/`

Ne jamais partir d'une page blanche : une bonne fiche recycle et structure ce que
Silex a déjà dit, elle n'invente pas une doctrine parallèle.

Vérifier aussi ce qui existe déjà dans `$HUB/09_COMMUNICATION/Infographies/README.md`
pour ne pas refaire une fiche publiée.

## Phase 1 — Plan de contenu → ARRÊT, VALIDATION HUMAINE

Proposer, en texte, **avant tout HTML** :

- Le **titre** (formule « Comment faire X » + une chute en accent) et les 4 à 5 **chips**
- Les **sections** (5 à 8), avec pour chacune son contenu réel rédigé, pas un placeholder
- Un bloc séparé : **toutes les affirmations factuelles, avec leur source**, et la mention
  explicite de ce qui est reconstitué ou supposé

Puis **s'arrêter et demander validation**.

> Ces fiches affirment des choses sous le nom d'un fondateur. Une approximation publiée
> coûte plus cher que trente secondes d'aller-retour. Ne jamais sauter cette étape,
> même si la demande semble pressée.

## Phase 2 — Assemblage

Dupliquer `template-poster.html` dans le dossier de la fiche, remplir, garder les invariants.

**Invariants (ne pas réinventer d'une fiche à l'autre)**

| Élément | Valeur |
|---|---|
| Largeur canvas | 1260 px, padding 40 px |
| Fond | papier `#fbf7f2` + blooms ciel/pêche + grille 60 px + grain 5 % |
| Badge auteur | **en haut**, centré, pilule navy, photo + « Prénom Nom \| gosilex.com » |
| Titre | centré, Manrope, `<b>` en encre pleine, chute en corail `#c9522c` |
| Chips | rangée sous le titre, la première en navy (« Cheat sheet ») |
| Sections | numérotées, en-tête coloré, couleurs `.t1`→`.t6` parcourant le dégradé signature |
| Panneau nuit | **un seul par fiche**, pour la section « friction » |
| CTA | bande en pied, **toujours la prise de rendez-vous** `cal.com/silex/30min` |
| Typo | Manrope (titres) + Inter (corps). **Aucun texte sous 12 px** |

**Règles d'écriture**

- Français, accents partout dans le contenu
- **Zéro tiret cadratin.** Deux-points, virgule ou point à la place
- Apostrophes typographiques `’` dans le corps HTML. Ne pas toucher à celles du CSS
  (noms de polices, data-URI du grain), ça casse le rendu
- Une thèse par section, pas une liste de généralités

**Logos d'outils** (seulement si le sujet l'exige)

Cascade, dans cet ordre : CDN officiel de la marque → SVG Wikimedia →
`https://www.google.com/s2/favicons?domain=X&sz=256` (avec `curl -L`, la redirection
est obligatoire sinon on récupère du HTML). Normaliser en 160 px carré transparent.

**Contrôler la planche complète sur fond blanc avant intégration** : beaucoup de favicons
sont blancs sur transparent et disparaissent. Si un logo est douteux ou sous 96 px,
**retirer l'outil de la fiche** plutôt que d'afficher un faux logo.

## Phase 3 — Calage du canvas

La hauteur n'est **jamais** choisie à la main.

```bash
scripts/render.sh <fiche.html> --measure              # hauteur naturelle du contenu
```

Reporter la valeur dans `height:` du `.canvas`, puis rendre normalement.

**Piège vérifié** : la mesure inclut le décalage du `body` (40 px). Le script le retranche
déjà. Ne pas ajouter de marge « au cas où » : ça crée une bande vide sous le CTA.

Largeur toujours 1260. Hauteur libre. Un ratio autour de 0,65 est le confort de lecture
visé, ce n'est pas une contrainte.

### La zone LinkedIn : 4:5, vérifié

**LinkedIn n'affiche en entier que jusqu'au ratio 4:5** (1080 × 1350). Au-delà, l'image est
rognée dans le fil et remplacée par un « voir l'image complète ».

À 1260 de large, la zone visible fait donc **1575 px**. Une fiche plus haute sera coupée :
c'est assumé, c'est ce que fait ColdIQ, l'image tronquée sert d'accroche et le clic
révèle le reste.

**Mais la coupe doit être choisie, pas subie.** Deux règles :

1. **La coupe tombe sur une fin de section**, jamais au milieu d'une carte. Une section
   tranchée en deux ne lit pas comme une accroche, elle lit comme une image cassée.
2. **Les 1575 premiers px doivent tenir seuls** : badge auteur, titre, chips, et au moins
   une rangée de sections complète. Quelqu'un qui ne clique jamais doit quand même
   avoir reçu quelque chose.

`render.sh` calcule le pourcentage visible et produit `*_linkedin_crop.jpg`, qui montre
exactement où tombe la coupe. **Le regarder avant de livrer.** Si la coupe tombe mal :
réordonner les rangées, ou ajuster une section pour déplacer la frontière.

Si le sujet tient en 1575 px, viser le 4:5 exact : l'image est alors entièrement visible,
ce qui reste le meilleur cas.

## Phase 4 — QA visuelle, obligatoire

Rendre, **puis regarder l'image**, pas seulement le code. Les bugs suivants ont tous été
attrapés à l'œil et étaient invisibles à la lecture du HTML :

- [ ] Rien n'est coupé en bas du canvas
- [ ] Aucune zone vide de plus de 80 px (une section trop courte à côté d'une longue)
- [ ] Un conteneur `display:flex` ne découpe pas une phrase en morceaux
- [ ] Un sélecteur trop large ne stylise pas les enfants (`.x div` attrape aussi les titres,
      utiliser `.x > div`)
- [ ] Aucun texte sous 12 px
- [ ] Les pilules ne s'étirent pas sur toute la largeur (`align-self:flex-start` dans un flex column)
- [ ] Tous les logos sont visibles sur leur tuile blanche
- [ ] `grep -c "—"` renvoie 0
- [ ] Lisible une fois réduit à 504 px de large (la taille réelle dans le fil LinkedIn)
- [ ] La coupe 4:5 tombe sur une fin de section (voir `*_linkedin_crop.jpg`)

Corriger et reboucler, **trois tours maximum**. Au-delà, signaler ce qui résiste plutôt
que de s'acharner.

## Phase 5 — Export et rangement

```
$HUB/09_COMMUNICATION/Infographies/
├── _assets/                      photo + logo, partagés par toutes les fiches
├── README.md                     index de la série, à mettre à jour
└── NN_Slug/
    ├── index.html                source éditable (pointe vers ../_assets/)
    ├── Infographie_<Slug>.png    export ×2
    ├── Infographie_<Slug>.jpg    même image, à privilégier pour l'upload
    └── POST.md                   le post LinkedIn + les sources
```

Numéroter la fiche à la suite, puis ajouter sa ligne au tableau du `README.md`.

## Phase 6 — Post LinkedIn → ARRÊT, VALIDATION HUMAINE

Rédiger selon `$HUB/02_BRAND/Voice_LinkedIn.md`, l'écrire dans `POST.md`, le proposer.

**Ne jamais publier.** Aucun post, aucun réseau, aucune automatisation d'envoi.

Rappeler à la personne : poster le **JPG**, et remplir le champ texte alternatif de
LinkedIn, il compte pour la portée.

## Publication Forge (optionnel)

Si la fiche doit aussi vivre en HTML sur `forge.gosilex.com` : enchaîner avec le skill
`forge-publish`. Ne pas réimplémenter la publication ici.

## Ce que ce skill ne fait pas

- Publier sur un réseau social
- Inventer un chiffre, un prix, un périmètre d'offre
- Recréer des tokens de design en dehors du template
- Stocker du contenu métier dans le skill
