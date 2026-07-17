---
name: silex-slides
description: Create stunning, animation-rich HTML presentations locked to the Silex art direction — luminous #FEFEFE grounds, cornflower-and-peach halo blooms, vintage risograph grain, Silex brand imagery, Instrument Serif + Hanken Grotesk + JetBrains Mono. Use when the user wants Silex-branded slides, a Silex deck/pitch, or to convert a PPT into the Silex design. This is the on-brand wrapper around frontend-slides — it skips style discovery and always generates the "Silex Halo" design system.
---

# Silex Slides

Build presentations in the **Silex Halo** design system — the Silex art direction applied to the `frontend-slides` engine. Every deck is automatically on-brand: near-white #FEFEFE grounds, cornflower/peach halo blooms, the signature dawn-halo, vintage grain, and Silex brand photography. No style-discovery phase — the brand is fixed.

## What this skill reuses

This skill is built on sibling skill `frontend-slides` in the **same plugin** (`silex-craft`). Resolve the engine root as:

`${CLAUDE_PLUGIN_ROOT}/skills/frontend-slides/`

(or relative sibling `../frontend-slides/` from this skill directory). Reuse its engine files directly — do NOT reinvent them:

- `${CLAUDE_PLUGIN_ROOT}/skills/frontend-slides/viewport-base.css` — the mandatory fixed-stage CSS. Include its FULL contents in every deck.
- `${CLAUDE_PLUGIN_ROOT}/skills/frontend-slides/html-template.md` — HTML architecture, navigation JS, inline-edit affordance.
- `${CLAUDE_PLUGIN_ROOT}/skills/frontend-slides/animation-patterns.md` — animation snippets (load reveals, staggered delays).
- `${CLAUDE_PLUGIN_ROOT}/skills/frontend-slides/scripts/deploy.sh` and `export-pdf.sh` — for Phase 4 sharing.

The ONLY thing this skill overrides is the design: it always uses `design-system.md` in THIS folder instead of the frontend-slides style-discovery flow.

## Phase 0: Detect mode
- **New deck** → Phase 1.
- **PPT conversion** → run `python ${CLAUDE_PLUGIN_ROOT}/skills/frontend-slides/scripts/extract-pptx.py <file.pptx> <out>`, confirm extracted content with the user, then Phase 2 (skip style discovery — style is always Silex Halo).
- **Enhance an existing Silex deck** → read it, apply the Mode C modification rules from `frontend-slides/SKILL.md` (count elements vs density before adding; split slides on overflow; verify 16:9 + no overflow after edits).

## Phase 1: Content discovery

Ask these together (use the structured-question UI if available), in French (Silex works in French):

1. **Objectif** — Pitch client / Présentation interne / Talk-conférence / Tutoriel-pédagogique
2. **Longueur** — Court 5-10 / Moyen 10-20 / Long 20+
3. **Contenu** — Tout prêt / Notes brutes / Juste le sujet
4. **Densité** — "Speaker-led" (peu de texte, grandes idées) / "Lecture" (slides autonomes, plus de détail)

Do NOT ask about visual style — it is always Silex Halo.

If the user has content, ask them to share it. If they mention images of their own, evaluate them as in `frontend-slides` Step 1.2; otherwise default to the bundled Silex assets in `assets/`.

## Phase 2: Generate

1. **Read the design recipe** — `design-system.md` in this folder. It is the single source of truth for palette, type, halo, grain, and hero imagery. Treat its frontmatter tokens and Implementation snippets as the build spec.
2. **Read the engine files** — `frontend-slides/viewport-base.css` (include in full), `frontend-slides/html-template.md`, `frontend-slides/animation-patterns.md`.
3. **Generate** a single self-contained HTML file, fixed 1920×1080 stage scaled to the viewport, all CSS/JS inline. Apply the user's density choice (see frontend-slides density modes).

**Silex Halo non-negotiables on every slide:**
- Ground is `#FEFEFE`; all text in ink `#031635`.
- At least one `sky-bloom` per surface (atmosphere).
- The `grain` overlay over EVERY surface (the brand texture signature).
- Cover + section surfaces carry a Silex hero photo (`assets/*.png`) with a paper scrim on the text side, OR the optional `night-poster` treatment (≤2 per deck).
- The `dawn-halo` on cover/closing surfaces.
- Instrument Serif display, Hanken Grotesk chrome/body, JetBrains Mono data. Accent (peach/cornflower) ≤ one word/stat per surface.
- Persistent JetBrains Mono pagenum bottom-right at 60% opacity.

**Assets — the single source of truth is `assets/` IN THIS SKILL FOLDER. Never copy it into a client folder.**
While authoring, reference brand images by their canonical name with a relative `assets/` path (`src="assets/clouds.png"`). Do NOT copy the files next to the deck and do NOT rename them — the build step in Phase 2.5 resolves each name from this skill's `assets/` and embeds it. That resolution is why the deck can live anywhere (a client folder, far from here) without a local `assets/` folder.
- **Hero photos:** `clouds.png`, `clouds_2.png`, `sunset.png`, `mountain_horizontal.png`, `man_looking_at_the_horizon.png`, `eye_looking_at_the_camera.png`, `hero-header.png` (night).
- **Brand marks:** `silex_small_logo.png`, `silex_small_logo_starry.png`, `silex-stone.png` (the flint/silex symbol — current site favicon mark).
- **Client logos (grey, for a "trusted by / ils nous font confiance" wall):** `logo-google-grey.png`, `logo-revenu-grey.png`, `logo-sia-grey.png`, `logo-antidox-grey.png` — flat-grey transparent silhouettes; drop on paper at ~60% opacity like the live site.
- **Client-specific image** (a logo or diagram only for this deck, e.g. `structure.svg`): put it in a temporary `assets/` folder next to the deck. Phase 2.5 also embeds those, then that folder can be deleted — the deck no longer needs it.
- For a moving cover, a looping `<video>` of clouds works (muted/autoplay/loop/playsinline) with the same scrim + grain. Videos are NOT embedded — keep the `.mp4` next to the deck (the only case where a file travels with the HTML).

## Phase 2.5: Make it self-contained (mandatory — this is what kills the copy problem)

Run the inliner on the generated deck:

```
python3 scripts/inline-assets.py "<path-to-deck>.html"
```

It replaces every `assets/…` reference with the image embedded as a base64 data URI — hero photos auto-compressed to JPEG (~×6 lighter), logos/marks kept as PNG, SVG inlined. The result is ONE portable `.html` with **no `assets/` folder to ship, copy, or lose** (a `.bak.html` is written first). A typical deck lands at ~1–2 Mo. After this step, no `assets/` folder should remain beside the deck (delete any temp one from a client-specific image; keep only a `.mp4` if the cover is a video).

## Phase 3: Verify & deliver
1. Open the **inlined** deck in a browser (`open <file>.html`). Screenshot at 1280×720 and one phone viewport. (Verifying the inlined file confirms every image survived embedding.)
2. Verify: stage stays 16:9, no text overflow, no panel overlap, grain visible, ink text legible over every hero scrim, blooms present.
3. Fix source and re-verify on any issue.
4. Tell the user: file location, slide count, navigation (←/→/Space), inline edit (hover top-left or press E), and how to tweak (`:root` variables for palette).

## Phase 4: Share (optional)

**Do NOT use Vercel** (`frontend-slides/scripts/deploy.sh`). Silex host = **forge.gosilex.com**.

```bash
# depuis le repo go-silex/silex-forge (ou marketplace silex-forge)
plugins/silex-forge/scripts/publish.sh mon-deck ./deck.html \
  --title "…" --type deck --share
# → interne Access /a/mon-deck/  + share unlisted /s/mon-deck/<key>/
```

PDF export remains: `bash ${CLAUDE_PLUGIN_ROOT}/skills/frontend-slides/scripts/export-pdf.sh <path>`.
After Phase 2.5 the deck is a self-contained `.html` (except video covers).

## Notes
- After Phase 2.5 the deck is ONE self-contained HTML file — no `assets/` folder beside it. The brand `assets/` folder lives only here in the skill and is never copied into a client/pipeline folder.
- Skipping Phase 2.5 is the classic bug: the deck then depends on a relative `assets/` folder that isn't there, so images 404 — or get duplicated into the client folder to compensate. Always inline.
- The grain can use the SVG `feTurbulence` filter; if a target browser shows perf issues, fall back to a tiled noise data-URI per the design-system snippet.
- "Silex" is a provisional name; keep the wordmark swappable (it's just `assets/silex_small_logo.png`).
