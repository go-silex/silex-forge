# Gemini prompt template

Generate one image per shot. Fill in the variables. Write the final prompt to a
temp file and pass it with `--prompt "@/tmp/shot-NN.txt"`.

The style is carried mostly by the attached `rocky-gold-*` references (soft
pastel painterly, heavy grain, simple Rocky, no text). The prompt's job is to:
invoke that look, forbid text, keep Rocky simple, and describe ONE clean scene.

```text
Generate a soft pastel painterly illustration with a heavy grainy / risograph-like noise texture, in the EXACT style of the attached reference images.

Style (match the references precisely):
A soft cornflower / periwinkle blue background with a warm peach-cream glow. Everything is soft-shaded painterly forms with a visible grain / noise texture all over (textured-paper / risograph feel). Gentle, dreamy, warm. NO hard ink outlines. Soft glows on light sources. ABSOLUTELY NO TEXT, NO LETTERS, NO LABELS, NO NUMBERS anywhere in the image.

Character (match the references exactly):
Rocky is a small, simple light-grey faceted STONE with two black dot eyes, a small mouth, and thin dark charcoal stick arms and legs. He stays minimal and iconic — never over-detailed. He performs the simple action of the scene.

Composition (SIMPLE and CLEAN — like the references: Rocky + one or two elements, lots of soft background space):
{describe a simple scene: where Rocky is, the one or two soft elements/objects with him, what he is doing — keep it to one clear, gentle visual idea}

Colors:
Cornflower blue, coral / salmon, peach-cream, light blue; grey Rocky with dark stick limbs. Soft warm glow on the key element.

Constraints:
Keep it SIMPLE and clean (Rocky + one or two elements), with lots of soft grainy background. Heavy grain texture everywhere. Soft pastel, no hard outlines, no flat vector, no busy machine. ABSOLUTELY NO text of any kind. Rocky stays simple and on-model. Match the exact look, palette, grain and mood of the attached reference images. Invent a fresh simple scene (don't copy a reference).
```

## How to pick the one visual idea

Turn the concept into ONE iconic image, not a diagram:
- a single symbolic object Rocky holds / offers / points to (a glowing brain, a key, a seed, a compass, a bridge),
- or a simple two-element contrast (small vs big, dim vs glowing, scattered vs gathered),
- or Rocky discovering / reacting to one glowing thing.
Let the soft rendering and the one clear gesture carry it. No labels — if you feel you need a word, find a clearer visual instead.

## Edit prompts

Pass the just-generated image as a reference and request a minimal edit.

Remove any text that slipped in:

```text
Edit the provided image. Keep everything identical — same composition, palette, grain, and the simple grey Rocky. ONLY remove any text, letters, numbers or labels, and fill those areas with the same soft grainy background / surface. Add no new text.
```

Fix Rocky if off-model:

```text
Edit the provided image. Keep the scene, palette and grain identical. Only adjust Rocky to match the attached references: a small simple light-grey faceted stone, two black dot eyes, a small mouth, thin dark charcoal stick limbs. Do not over-detail him. Change nothing else.
```

Strengthen the grain / pastel if it came out flat:

```text
Edit the provided image. Keep the composition and character identical. Re-render it softer and more painterly with a stronger grain / risograph noise texture all over, in the cornflower-blue + peach pastel palette of the attached references. Remove any hard outlines or flat-vector look.
```
