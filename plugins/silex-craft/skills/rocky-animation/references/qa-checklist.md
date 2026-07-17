# QA checklist

Open the generated PNG with the Read tool and look at it before delivering.

## Must pass

- **Soft pastel painterly look with a strong, visible GRAIN / noise texture all over.** Not flat, not clean-vector. (Signature check.)
- **ZERO text**: no words, letters, numbers, or labels anywhere. (Hard rule — if any text appears, edit it out.)
- **Pastel palette**: cornflower / periwinkle blue background, warm peach-cream glow, coral / blue objects. Soft glows, no hard outlines.
- **Rocky is SIMPLE and on-model**: a small light-grey faceted stone, dot eyes, small mouth, thin dark stick limbs. Not over-detailed, not a smooth egg.
- **Simple, clean composition**: Rocky + one or two elements, lots of soft background space. NOT busy, NOT a complex machine.
- One clear, gentle visual idea; calm and warm mood.
- Did NOT copy a reference composition.

## Failure signals (regenerate or local-edit)

- **Any text / letters / numbers** crept in → use the "remove text" edit prompt.
- Flat / clean render with no grain, or hard ink outlines / flat-vector look.
- Busy, cluttered, or a complex mechanical contraption (that was the old direction — keep it simple now).
- Rocky over-detailed or off-model (smooth egg, wrong shape, wrong colour).
- Colors off the palette (too saturated, neon, or non-pastel).
- Mood cold or harsh instead of warm and gentle.

## Iteration moves

- Text appeared: local-edit with the "remove text" prompt (this is the most common fix).
- Too flat / no grain: local-edit with the "strengthen grain / pastel" prompt.
- Too busy: regenerate simpler — Rocky + one element, more soft background.
- Rocky off-model: local-edit to restore the simple faceted grey stone (references attached).

## Delivery judgment

A good image looks like it belongs in the reference set: a soft, grainy, warm pastel frame with a simple grey Rocky and one glowing idea, and not a single word of text. Compare against `rocky-gold-02-brain.png` / `rocky-gold-05-box.png`. If it's flat/vector, has any text, is busy, or Rocky is off-model, it fails.
