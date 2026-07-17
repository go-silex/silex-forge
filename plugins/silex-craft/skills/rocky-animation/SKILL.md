---
name: rocky-animation
description: Generate soft pastel painterly illustrations with a grainy / risograph texture, featuring a recurring simple grey stone character named Rocky, using Gemini 3 Pro Image (Nano Banana Pro). Use when the user wants body illustrations, article figures, "illustration suggestions", a "shot list", or wants to turn a judgment, idea, state or metaphor into one clean 16:9 illustration. Default: cornflower-blue-to-peach pastel background, heavy grain texture, soft glows, simple Rocky + one or two elements, ZERO text, anchored by the rocky-gold-* reference images, generated via the Gemini API.
---

# Rocky Illustrations (Nano Banana Pro)

Turn a concept into one soft, pastel, grainy painterly illustration. Not a diagram, not a PPT infographic, not a line-art doodle. One image conveys exactly one clear, gentle visual idea.

The recurring character is **Rocky**: a small, simple light-grey faceted stone with dot eyes, a small mouth, and thin dark stick limbs. He and the style are anchored at generation time by the reference images in `assets/templates/` (the `rocky-gold-*` pastel targets).

**The core principle: SIMPLE Rocky, SIMPLE clean scene, ZERO text, and a lush pastel + GRAIN render.** Rocky stays minimal and iconic. Compositions stay simple — Rocky + one or two soft-glowing elements, lots of background space (like the references), NOT a busy machine. The richness lives in the painterly grainy rendering and the warm pastel palette, not in clutter. Never put any text/labels in the image. See `references/style-dna.md` and `references/prompt-template.md`.

**No text at all.** The image must contain zero words, letters, numbers, or labels — find a clearer visual instead.

## Read these references as needed (don't dump them all into context)

- `references/style-dna.md` — the pastel + grain look, palette, no-text rule, hard nos.
- `references/character-ip.md` — Rocky's look (keep him simple), action vocabulary.
- `references/composition-patterns.md` — ways to turn a concept into ONE simple iconic visual.
- `references/prompt-template.md` — the exact prompt to send to Gemini.
- `references/qa-checklist.md` — what to check after generation.
- `assets/templates/` — character + style reference images. Do NOT copy their exact compositions; they calibrate Rocky and the palette.

## Workflow

### 1. Digest the article

Read the user's text / link / Markdown / Notion content / screenshot. Extract:
- the core point,
- which paragraphs carry a cognitive turn,
- what is worth illustrating vs. text-only.

Don't illustrate evenly. Pick "cognitive anchors": a key judgment, two breakpoints, an input→output loop, a split, a before/after, a handoff path, a common pit, a role state change.

### 2. Shot list first

If the user just wants planning ("analyze where to add figures", "give me a shot list"), output the list and STOP before generating. For each shot:
- where it goes (after which paragraph),
- topic,
- core idea,
- the one simple visual idea (the symbolic object / scene),
- what Rocky is doing (his simple action),
- (no text — there are never any labels on the image).

Default 4-8 shots. Short article: 1-3. Long article: rarely above 9.

### 3. Generate (one image per shot)

If the user clearly asks to generate ("generate / make the images / produce"), do NOT stop to confirm. For each shot:

1. Build the prompt from `references/prompt-template.md`. Write it to a temp file (e.g. `/tmp/rocky-shot-NN.txt`) to avoid shell-escaping issues.
2. Run the generator via the wrapper. `<skill-dir>` is THIS skill's base directory (shown to you when the skill is invoked — it may be a personal path or the shared silex-hub vault). The wrapper auto-creates its Python env on first run and reads the API key from the environment or Keychain. `--templates-dir` defaults to this skill's `assets/templates`, so you don't need to pass it:

```bash
bash "<skill-dir>/scripts/gen.sh" \
  --prompt "@/tmp/rocky-shot-01.txt" \
  --out "<workspace>/assets/<article-slug>-illustrations/01-topic-name.png"
```

One image per shot. Never combine multiple figures into one image. The reference images are passed automatically by the script, so Rocky and the palette stay consistent without re-describing them in full each time (still describe what Rocky is DOING).

### 4. QA each image (this is the Claude advantage)

After each generation, **open the saved PNG with the Read tool and actually look at it.** Check against `references/qa-checklist.md`. Regenerate or locally edit if:
- ANY text / letters / numbers appear (hard rule) — edit them out,
- the render came out flat / vector with no grain (it must be soft pastel + heavy grain),
- Rocky is over-detailed or drifted off-model (smooth egg, wrong shape/colour),
- the composition is busy / cluttered instead of simple (Rocky + one or two elements),
- colors drift off the pastel palette (neon, oversaturated),
- it copies one of the `assets/templates/` compositions.

To fix the character, the setting, or wrong text, use the edit prompts in `references/prompt-template.md` (pass the just-generated image as an additional reference and ask for a minimal edit).

### 5. Deliver

Save final PNGs to `assets/<article-slug>-illustrations/` in the user's workspace, named in order:

```
01-topic-name.png
02-topic-name.png
```

Don't overwrite existing assets unless asked. Report: how many generated, each one's purpose, the save path, which are strongest, which are optional.

## Setup

`gen.sh` auto-creates its Python environment on first run (a machine-local venv under `~/.cache/rocky-animation/`, outside the vault — so it never syncs via Drive). The ONLY thing each user must provide once is a Gemini API key:

```bash
# Gemini API key (Nano Banana Pro) — once per machine (first match wins in gen.sh)

# Linux / portable (recommended):
mkdir -p ~/.config/silex
echo 'YOUR_GEMINI_KEY' > ~/.config/silex/gemini-api-key
chmod 600 ~/.config/silex/gemini-api-key

# or env:
export GEMINI_API_KEY='YOUR_GEMINI_KEY'

# or macOS Keychain:
security add-generic-password -s GEMINI_API_KEY -a gosilex -w 'YOUR_GEMINI_KEY'
```

The model used is `gemini-3-pro-image-preview` (Nano Banana Pro). Rocky + the style live entirely in `assets/templates/` (the `rocky-gold-*` references): swap those images to change the character or look.

## Portability

Shipped via plugin **silex-craft** (not the vault):
- Code + references live in the plugin; Python venv under `~/.cache/rocky-animation/` (per machine).
- Each operator needs `GEMINI_API_KEY` (`~/.config/silex/gemini-api-key`, env, or macOS Keychain) — never in the vault/repo.
- Requires `python3`.
