---
version: alpha
name: Silex Halo
slug: silex-halo
description: "A luminous, atmospheric presentation system in the Silex art direction — near-white #FEFEFE grounds flooded with soft cornflower-blue and peach radial 'halo' blooms, set against a single deep-navy ink. A vintage risograph grain sits over every surface. Display type is Instrument Serif; chrome is Hanken Grotesk; data is JetBrains Mono. Full-bleed Silex brand imagery (cloud seas, sunsets, horizons) anchors cover and section surfaces. The mood is dawn light over a cloud sea: calm, optimistic, poetic, AI-native — quiet but never cold."

# === SILEX PALETTE ===
# Aligned to the LIVE site design tokens (gosilex.com, "Atmospheric Precision"):
#   --primary #031635 (navy ink), --secondary #2e5f9d (interactive blue / italic emphasis),
#   the cornflower halo rgba(107,159,212) = #6B9FD4, peach cloud accents, surface #f8f9fa/#FEFEFE.
colors:
  paper: "#FEFEFE"        # dominant light ground — never pure #FFF, never gray
  paper-deep: "#EEF2F7"   # cool off-white secondary surface / shadow band without shadow
  mist: "#DCE7F2"         # pale blue-grey for hairline tints and soft panels
  sky: "#6B9FD4"          # cornflower — the signature Silex halo blue (site .sky-bloom = rgba(107,159,212))
  sky-soft: "#A8C2D8"     # pale cornflower, mid-stop of sky-blooms
  haze: "#D4E4EF"         # palest sky blue, outer bloom extension into paper
  secondary: "#2e5f9d"    # site interactive blue — the emphasis-word / link color (site italic emphasis)
  peach: "#EB7457"        # coral/peach accent — the cloud highlight & sunset sun
  peach-soft: "#F2B49A"   # softer peach, mid-stop of peach-blooms
  bronze: "#B8976E"       # warm sand, mid-stop of the dawn-halo
  ink: "#031635"          # deep navy — the single universal text & rule color (= site --primary)
  ink-soft: "#1a2b4b"     # lighter navy, ONLY for optional night-poster grounds (= site --primary-container)

color-aliases:
  line: ink

# === TYPOGRAPHY ===
# Shared with the live site: ONLY JetBrains Mono (data/labels) + the halo/grain/imagery DNA.
# The site itself uses Manrope (display, with faux-italic emphasis) + Inter (body).
# The deck deliberately keeps a richer EDITORIAL voice for presentation gravitas:
#   Instrument Serif = display/quote (the "poetry" value), Hanken Grotesk = body/chrome.
# This is an intentional deck<>web distinction, not an inconsistency. Playfair Display is an
# optional heavier poster-display alt. To make decks match the site 1:1, swap display ->
# Manrope and body -> Inter (single change in this file + the :root snippet).
typography:
  display:
    fontFamily: "'Instrument Serif', Georgia, serif"
    fontWeight: 400
    fontSize: "clamp(120px, min(14.6vw, 22vh), 240px)"
    lineHeight: 0.88
    letterSpacing: -0.018em
  display-md:
    fontFamily: "'Instrument Serif', Georgia, serif"
    fontWeight: 400
    fontSize: "clamp(80px, min(10vw, 16vh), 200px)"
    lineHeight: 0.9
    letterSpacing: -0.015em
  display-it:
    fontFamily: "'Instrument Serif', Georgia, serif"
    fontWeight: 400
    fontStyle: italic
    fontSize: "clamp(56px, min(7vw, 11vh), 120px)"
    lineHeight: 1.04
    letterSpacing: -0.005em
  display-poster:
    fontFamily: "'Playfair Display', Georgia, serif"
    fontWeight: 700
    fontSize: "clamp(96px, min(11vw, 18vh), 200px)"
    lineHeight: 0.96
    letterSpacing: -0.01em
    note: "Optional heavier display for the single boldest poster moment. Use sparingly; Instrument Serif remains primary."
  numeral-jumbo:
    fontFamily: "'Instrument Serif', Georgia, serif"
    fontWeight: 400
    fontSize: "clamp(220px, min(28vw, 64vh), 720px)"
    lineHeight: 0.84
    letterSpacing: -0.04em
  numeral-md:
    fontFamily: "'Instrument Serif', Georgia, serif"
    fontWeight: 400
    fontSize: "clamp(72px, min(7vw, 12vh), 144px)"
    lineHeight: 0.92
    letterSpacing: -0.01em
  headline:
    fontFamily: "'Instrument Serif', Georgia, serif"
    fontWeight: 400
    fontSize: "clamp(40px, min(4.6vw, 7vh), 88px)"
    lineHeight: 1.06
    letterSpacing: -0.005em
  headline-sm:
    fontFamily: "'Instrument Serif', Georgia, serif"
    fontWeight: 400
    fontSize: "clamp(32px, min(3.6vw, 6vh), 56px)"
    lineHeight: 1.02
  body-lede:
    fontFamily: "'Hanken Grotesk', system-ui, sans-serif"
    fontWeight: 400
    fontSize: "clamp(15px, 1.05vw, 19px)"
    lineHeight: 1.55
  body:
    fontFamily: "'Hanken Grotesk', system-ui, sans-serif"
    fontWeight: 400
    fontSize: "clamp(14px, 0.95vw, 16px)"
    lineHeight: 1.5
  body-sm:
    fontFamily: "'Hanken Grotesk', system-ui, sans-serif"
    fontWeight: 400
    fontSize: "clamp(11px, 0.78vw, 13px)"
    lineHeight: 1.5
  micro-label:
    fontFamily: "'Hanken Grotesk', system-ui, sans-serif"
    fontWeight: 600
    fontSize: "clamp(11px, 0.85vw, 14px)"
    lineHeight: 1.2
    letterSpacing: 0.2em
    textTransform: uppercase
  rail-label:
    fontFamily: "'Hanken Grotesk', system-ui, sans-serif"
    fontWeight: 600
    fontSize: "clamp(11px, 0.85vw, 13px)"
    lineHeight: 1
    letterSpacing: 0.34em
    textTransform: uppercase
  mono-data:
    fontFamily: "'JetBrains Mono', ui-monospace, monospace"
    fontWeight: 400
    fontSize: "clamp(12px, 0.85vw, 14px)"
    lineHeight: 1.4
    letterSpacing: 0.04em
  pagenum:
    fontFamily: "'JetBrains Mono', ui-monospace, monospace"
    fontWeight: 400
    fontSize: "clamp(11px, 0.85vw, 13px)"
    lineHeight: 1
    letterSpacing: 0.08em

# Google Fonts load string:
# https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Playfair+Display:wght@600;700&family=Hanken+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400&display=swap

spacing:
  pad-edge: "clamp(40px, 4vw, 80px)"
  pad-region: "clamp(40px, 4.2vw, 80px)"
  gap-region: "clamp(20px, 2.5vw, 48px)"
  gap-strand: "clamp(14px, 1.8vh, 22px)"
  pagenum-bottom: "clamp(22px, 2.4vh, 42px)"
  pagenum-right: "clamp(24px, 2.4vw, 48px)"

canvas:
  width: 1920
  height: 1080
  background: "{colors.paper}"

components:
  # --- The Silex halo: the primary atmospheric layer (recolored from Biennale's sun-bloom) ---
  sky-bloom:
    background: "radial-gradient using {colors.sky} {colors.sky-soft} {colors.haze} blending to transparent on {colors.paper}"
    description: "Large soft cornflower radial bloom placed off-center or behind a focal element. The system's primary atmospheric layer. Sized 42-70% of the stage. The Silex equivalent of a sunlit cloud edge."
  peach-bloom:
    background: "radial-gradient using {colors.peach} {colors.peach-soft} at 14-22% opacity blending to transparent"
    description: "Small warm peach bloom used as a counter-temperature accent in a corner opposite the sky-bloom. Always subordinate. This is the coral 'sun catching the cloud' from the brand imagery."
  # --- The signature site halo, kept per user request ---
  dawn-halo:
    background: "radial-gradient(ellipse at 50% 118%, {colors.haze} 0%, {colors.peach-soft} 16%, {colors.sky-soft} 40%, {colors.sky} 62%, transparent 82%)"
    description: "The Silex site's signature bottom-rising halo, recolored for the light system: a warm-to-cool dawn glow blooming up from below the stage into the paper. Used on cover and closing surfaces. THIS IS THE 'gradient halo' the brand is known for — keep it luminous, never muddy."
  # --- Vintage grain: the Silex texture signature (NEW) ---
  grain:
    technique: "SVG feTurbulence fractalNoise overlay, fixed full-stage, pointer-events none"
    blend: "mix-blend-mode: soft-light"
    opacity: "0.12 - 0.18"
    params: "baseFrequency 0.85, numOctaves 3"
    description: "A risograph / vintage film grain laid over EVERY surface, matching the texture baked into the Silex brand photos (clouds.png, sunset.png). Non-optional — it is what makes a Silex surface read as Silex and not as a generic light deck. See grain CSS in the Implementation section."
  # --- Hero imagery: full-bleed Silex brand assets (NEW) ---
  hero-bleed:
    layout: "full-bleed image or looping <video> behind content, with a paper→transparent scrim on the content side for text legibility"
    scrim: "linear-gradient from {colors.paper} (95-100%) on the text edge to transparent over the image"
    assets: "assets/clouds.png, assets/clouds_2.png, assets/sunset.png, assets/mountain_horizontal.png, assets/man_looking_at_the_horizon.png (light); assets/hero-header.png (night-poster). Reference by relative path."
    description: "A Silex brand photograph bled to an edge or full surface on cover/section slides. The grain in these photos and the system grain reinforce each other. Always keep ink text on the paper-scrimmed side, never over the busy part of the image."
  hairline-rule:
    border: "1px solid {colors.ink}"
    description: "1px solid ink rule — the only border treatment. Separates header bands, list rows, footer columns. No thicker rule exists."
  hairline-rule-soft:
    border: "1px solid rgba(3,22,53, 0.16)"
    description: "1px ink at ~16% for secondary row separators in dense lists."
  blue-panel:
    background: "{colors.sky}"
    color: "{colors.paper}"
    description: "Full-bleed cornflower panel covering a column or third of the stage. The strongest color statement on a light surface — paper text sits on top. The Silex analogue of Biennale's yellow-panel."
  night-poster:
    background: "{colors.ink} ground with a {components.dawn-halo} rising from below"
    color: "{colors.paper}"
    description: "OPTIONAL deep-navy full-bleed surface (the site/hero-header mood). Paper text + dawn-halo + sky/peach blooms. Reserved for the single most dramatic divider or closing moment. Light surfaces remain the default — use night-poster at most once or twice per deck."
  pagenum:
    position: "absolute, right + bottom"
    color: "{colors.ink}"
    opacity: 0.6
    description: "Single JetBrains Mono NN / NN pinned bottom-right of every surface. On night-poster surfaces it flips to {colors.paper} at 0.6."
  strand-row:
    layout: "grid 56px 1fr, gap clamp(14px,1.4vw,24px), border-bottom hairline-soft"
    description: "Numbered editorial list row: serif numeral + content cell. For programmes, agendas, curated lists."
  vertical-rail:
    transform: "rotate(-90deg) at left edge"
    description: "Rotated Hanken Grotesk uppercase label up the left edge of divider surfaces."
---

## Frontend Slides Fixed-Stage Policy

This design system is used by the `/silex-slides` skill, which is built on the `frontend-slides` engine. Generate the final deck as a **fixed 1920×1080 stage** that scales uniformly to the viewport. Preserve a 16:9 canvas on every screen including phones — letterbox/pillarbox is fine; never reflow slide content for mobile. Use the `frontend-slides` `viewport-base.css` (include its full contents) and its `.active`/`.visible` visibility model. Do not switch slides with `display:none/block`.

## Overview

Silex Halo is the Silex art direction expressed as a presentation system. Where Biennale Yellow is *warm parchment + solar yellow*, Silex Halo is *luminous near-white + cornflower-and-peach dawn light*. It is the world of the Silex brand photography: a sea of clouds at first light, a peach sun low over blue water, a lone figure walking toward a glowing arch. Calm, optimistic, poetic — the feeling of an AI-native company that turns a conversation into a finished thing overnight.

The structural vocabulary is four things: **paper, ink, halo, grain.** No cards, no buttons, no drop shadows, no rounded corners. Color comes from atmospheric blooms and full-bleed brand imagery, not from filled boxes. The grain is the connective tissue — it sits over everything and ties the CSS surfaces to the photographs.

**Key characteristics:**
- Near-white `{colors.paper}` (#FEFEFE) ground on every surface — never pure white, never gray.
- Single ink color `{colors.ink}` (#031635 deep navy) for all text and all rules.
- Cornflower `{colors.sky}` + peach `{colors.peach}` deployed as soft radial **halos**, never as flat fills (except the occasional `blue-panel`).
- The signature `{components.dawn-halo}` — the site's bottom-rising gradient glow — on cover/closing surfaces.
- A vintage risograph **grain** over every surface (`{components.grain}`), matching the texture in the brand photos.
- Full-bleed Silex **brand imagery** (`{components.hero-bleed}`) anchoring cover and section surfaces.
- Instrument Serif for every display moment; Hanken Grotesk for chrome/body; JetBrains Mono for data.
- 1px hairline ink rules are the only border treatment. No shadows, no radius.
- Persistent `NN / NN` JetBrains Mono pagenum bottom-right at 60% opacity.

## Colors

- **Paper** `#FEFEFE` — the luminous near-white ground. Default and near-universal. Softer than pure white; reads as morning light.
- **Paper-deep** `#EEF2F7` — cool off-white secondary surface; suggests a soft band without a shadow.
- **Mist** `#DCE7F2` — pale blue-grey for soft panels and tinted hairlines.
- **Sky** `#6B9FD4` — cornflower, the signature Silex blue. The core of sky-blooms; fills a `blue-panel`; tints rail labels.
- **Sky-soft** `#A8C2D8` / **Haze** `#D4E4EF` — the mid and outer stops that let a sky-bloom dissolve into paper without a hard edge.
- **Secondary** `#2e5f9d` — the site's interactive blue (the colour of the italic emphasis on gosilex.com). Use it for the single emphasis word / link tint on a surface — the deck analogue of the site's italic accent. Cornflower `sky` and `peach` remain the other accent options.
- **Peach** `#EB7457` — coral accent (the sunlit cloud edge, the sunset sun). Used in counter-blooms, for a single emphasis word, or a hero stat. Never a large flat fill.
- **Peach-soft** `#F2B49A` — softer peach for bloom mid-stops and the warm base of the dawn-halo.
- **Bronze** `#B8976E` — warm sand, optional warm mid-stop in the dawn-halo.
- **Ink** `#031635` — the single text & rule color across the system (= site `--primary`). Deep navy reading as confident near-black with blue bias.
- **Ink-soft** `#1a2b4b` — used ONLY as the ground of an optional `night-poster` surface, never as text (= site `--primary-container`).

### Color discipline

Text is **ink by default, everywhere.** Silex Halo relaxes Biennale's absolute single-color rule by exactly one allowance: **peach or cornflower may color a single emphasis word, a single hero stat, or a micro-label per surface** — never a paragraph, never a headline in full. Accent otherwise lives in the blooms, the dawn-halo, and the photographs, not in the type. On a `night-poster` surface, text flips to `{colors.paper}`. There is no other inversion.

## Typography

Three roles. The live site uses **Manrope** (display, with faux-italic emphasis) + **Inter** (body) + **JetBrains Mono**. The deck shares JetBrains Mono and the full halo/grain/imagery DNA, but deliberately runs a richer **editorial** display voice — a literary serif carries the Silex "poetry" value better than a geometric sans in a presentation context. (If you'd rather the deck match the site 1:1, swap Instrument Serif → Manrope and Hanken Grotesk → Inter; see the typography frontmatter note.)

- **Instrument Serif** — every display moment, numeral, and quote, weight 400, tight line-height (0.84–1.06), negative tracking. Italic is the quote/manifesto voice — the deck's equivalent of the site's italic emphasis. **Playfair Display 700** is an optional heavier alternate for the single boldest poster headline — use rarely; Instrument Serif stays primary.
- **Hanken Grotesk** — the sans voice for body, ledes, and the universal micro-label (weight 600, uppercase, 0.2em+ tracking): clean, modern, a touch warmer than Inter.
- **JetBrains Mono** (shared with the site) — exclusively numerical/metadata chrome: dates, stats, chart values, page numbers.

### Signature treatments (non-optional when the element type is used)
- Every display/numeral/headline element is Instrument Serif 400 with tight line-height and negative tracking. Never bold the serif (except the surgical Playfair poster alt).
- Every micro-label is Hanken Grotesk 600, uppercase, ≥0.2em tracking.
- Every body paragraph is Hanken Grotesk 400, line-height ≥1.45. No serif body.
- Every date/stat/page number is JetBrains Mono.

## Atmosphere, halo & grain

Depth is **atmospheric, never structural** — zero drop shadows anywhere. Depth comes from three layers:

1. **Sky-bloom** (`{components.sky-bloom}`) — at least one per surface. A flat #FEFEFE surface with no bloom reads as broken. Anatomy (radial-gradient, 3–4 stops): `sky` 60–90% at core → `sky` 40–55% → `haze` 18–22% → `paper` 0%.
2. **Peach-bloom** (`{components.peach-bloom}`) — optional counter-temperature accent in the opposite corner, 14–22% opacity, always smaller and subordinate to the sky-bloom.
3. **Dawn-halo** (`{components.dawn-halo}`) — the brand-signature bottom-rising glow on cover/closing surfaces. Keep it luminous: warm peach base → cornflower → fade into paper. Never let the stops muddy into grey.

**Grain** (`{components.grain}`) sits over ALL of the above and over any hero image. It is the Silex texture signature — see the exact snippet in Implementation. Opacity 0.12–0.18, `mix-blend-mode: soft-light`. Without it, surfaces look like a generic SaaS deck; with it, they match the brand photographs.

## Hero imagery

Cover and section surfaces may carry a full-bleed Silex photograph (`{components.hero-bleed}`):
- **Light heroes:** `assets/clouds.png`, `assets/clouds_2.png`, `assets/sunset.png`, `assets/mountain_horizontal.png`, `assets/man_looking_at_the_horizon.png`.
- **Night-poster hero:** `assets/hero-header.png` (the glowing arch — pair with the night-poster surface).
- **Logo:** `assets/silex_small_logo.png` (white wordmark, place on ink/blue) — recolor to ink via CSS only on light grounds, or use as-is on dark.

Reference by **relative path** (`src="assets/clouds.png"`). Always lay a `{colors.paper}`→transparent scrim on the text side so ink stays legible, and keep the grain on top. A looping `<video>` (e.g. the cloud animation) may replace a still on the cover — muted, autoplay, loop, `playsinline`, with the same scrim + grain.

## Do / Don't

**Do**
- Start every surface on `{colors.paper}` (#FEFEFE) and place at least one `{components.sky-bloom}`.
- Set all text in `{colors.ink}`; reserve peach/cornflower for one emphasis moment per surface.
- Lay the `{components.grain}` over every surface — it is non-optional.
- Use the `{components.dawn-halo}` on cover/closing surfaces; keep it luminous.
- Bleed a Silex brand photo on cover/section surfaces with a paper scrim on the text side.
- Use Instrument Serif 400 (tight, negative-tracked) for display; Hanken Grotesk 600 uppercase for labels.
- Pin the JetBrains Mono pagenum bottom-right at 60% opacity.

**Don't**
- Don't use pure `#FFFFFF` or any neutral gray as the ground — the warmth-cool of #FEFEFE + blooms is the point.
- Don't omit the grain. A grain-less surface is off-brand.
- Don't add drop shadows or round any corner. Borders are 1px ink hairlines only.
- Don't color a headline or paragraph in peach/cornflower — accent is one word max.
- Don't muddy the dawn-halo into grey, and don't let ink text sit over the busy part of a photo.
- Don't bold Instrument Serif (use the Playfair poster alt instead, sparingly).
- Don't overuse `night-poster` — light #FEFEFE surfaces are the default; dark is at most once or twice per deck.
- Don't substitute Inter/Helvetica/system-ui for Hanken Grotesk, or Times for Instrument Serif.

## Implementation snippets

### Font loading (`<head>`)
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Playfair+Display:wght@600;700&family=Hanken+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400&display=swap" rel="stylesheet">
```

### CSS variables (`:root`)
```css
:root{
  --paper:#FEFEFE; --paper-deep:#EEF2F7; --mist:#DCE7F2;
  --sky:#6B9FD4; --sky-soft:#A8C2D8; --haze:#D4E4EF;
  --secondary:#2e5f9d;
  --peach:#EB7457; --peach-soft:#F2B49A; --bronze:#B8976E;
  --ink:#031635; --ink-soft:#1a2b4b;
}
```

### Sky-bloom (primary atmosphere — one per surface)
```css
.sky-bloom{position:absolute;inset:0;pointer-events:none;
  background:radial-gradient(60% 55% at 68% 32%,
    rgba(107,159,212,.55) 0%, rgba(107,159,212,.34) 32%,
    rgba(212,228,239,.20) 58%, rgba(254,254,254,0) 82%);}
```

### Peach counter-bloom (subordinate)
```css
.peach-bloom{position:absolute;inset:0;pointer-events:none;
  background:radial-gradient(40% 38% at 16% 84%,
    rgba(235,116,87,.20) 0%, rgba(242,180,154,.12) 40%, rgba(254,254,254,0) 74%);}
```

### Dawn-halo (signature, cover/closing — rises from below)
```css
.dawn-halo{position:absolute;inset:0;pointer-events:none;
  background:radial-gradient(70% 62% at 50% 118%,
    rgba(212,228,239,.0) 0%, rgba(242,180,154,.42) 14%,
    rgba(184,151,110,.30) 26%, rgba(168,194,216,.42) 46%,
    rgba(107,159,212,.40) 64%, rgba(254,254,254,0) 84%);}
```

### Vintage grain (SIGNATURE — over every surface)
```html
<!-- place once near the stage; reuse the .grain overlay on each slide -->
<svg width="0" height="0" style="position:absolute">
  <filter id="silexGrain"><feTurbulence type="fractalNoise"
    baseFrequency="0.85" numOctaves="3" stitchTiles="stitch"/>
  </filter>
</svg>
```
```css
.grain{position:absolute;inset:0;pointer-events:none;z-index:50;
  opacity:.15; mix-blend-mode:soft-light;
  filter:url(#silexGrain);}            /* or use a data-URI noise PNG fallback */
/* Fallback if filter perf is an issue: a tiled noise data-URI background-image
   at the same opacity + blend mode. */
```

### Hero photo with paper scrim (legible text side)
```css
.hero-bleed{position:absolute;inset:0;z-index:0;overflow:hidden;}
.hero-bleed img,.hero-bleed video{width:100%;height:100%;object-fit:cover;}
.hero-scrim{position:absolute;inset:0;
  background:linear-gradient(100deg, var(--paper) 0%, rgba(254,254,254,.92) 30%,
    rgba(254,254,254,.55) 52%, rgba(254,254,254,0) 78%);}
```

### Night-poster (optional, ≤2 per deck)
```css
.night{background:var(--ink);color:var(--paper);}
.night .pagenum{color:var(--paper);}
/* keep .dawn-halo + .grain on top; text in --paper, accent peach/sky as before */
```

## Slide archetypes
- **Cover** — hero photo bleed (clouds/sunset) OR night-poster + dawn-halo; Instrument Serif title 120–240px; Silex wordmark or micro-label eyebrow; mono date bottom; grain over all.
- **Section divider** — jumbo Instrument Serif numeral (220–720px) or a vertical rail label; single sky-bloom; minimal text.
- **Statement / quote** — italic Instrument Serif (`display-it`) centered on paper with a soft sky-bloom; one peach emphasis word allowed.
- **Content / list** — paper ground, sky-bloom, `strand-row` numbered list or a 2–3 column grid separated by hairline rules; Hanken Grotesk body.
- **Stat** — JetBrains-Mono-labelled Instrument Serif `numeral-md` figure; peach (or `secondary` blue) allowed on the single hero number.
- **Logo wall (trusted-by)** — paper ground + soft sky-bloom; a `micro-label` eyebrow ("ILS NOUS FONT CONFIANCE"), then the grey client logos (`logo-*-grey.png`) on a single row/grid at ~60% opacity, optically sized (Sia is wide), separated by air not rules. Mirrors the live site.
- **Closing** — dawn-halo rising; Instrument Serif sign-off; wordmark or `silex-stone.png`; mono contact line.
