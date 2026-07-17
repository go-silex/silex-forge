#!/usr/bin/env python3
"""Generate ONE hand-drawn article illustration with Gemini 3 Pro Image
(a.k.a. Nano Banana Pro), anchored on a folder of character reference images.

Usage:
    python generate_image.py \
        --prompt "@/tmp/shot.txt" \
        --templates-dir ~/.claude/skills/xiaohei-illustrations/assets/templates \
        --out ./assets/my-article-illustrations/01-topic.png

The prompt may be inline text or "@path" to read it from a file (preferred for
long prompts, avoids shell-escaping issues).

Requires GEMINI_API_KEY in the environment (the gen.sh wrapper pulls it from the
macOS Keychain).
"""
import argparse
import glob
import os
import sys
from pathlib import Path

MODEL = "gemini-3-pro-image-preview"  # Nano Banana Pro
IMG_EXTS = ("*.png", "*.jpg", "*.jpeg", "*.webp")


def load_refs(templates_dir, limit):
    files = []
    for ext in IMG_EXTS:
        files.extend(sorted(glob.glob(os.path.join(os.path.expanduser(templates_dir), ext))))
    return files[:limit]


def mime_for(path):
    p = path.lower()
    if p.endswith(".png"):
        return "image/png"
    if p.endswith(".webp"):
        return "image/webp"
    return "image/jpeg"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt", required=True, help='Prompt text, or "@path" to read from a file')
    _default_templates = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "templates")
    ap.add_argument("--templates-dir", default=_default_templates, help="Folder of character reference images (default: the skill's assets/templates)")
    ap.add_argument("--out", required=True, help="Output PNG path")
    ap.add_argument("--aspect-ratio", default="16:9")
    ap.add_argument("--resolution", default="2K", help="1K | 2K | 4K")
    ap.add_argument("--max-refs", type=int, default=8)
    ap.add_argument("--model", default=MODEL)
    args = ap.parse_args()

    prompt = args.prompt
    if prompt.startswith("@"):
        prompt = Path(os.path.expanduser(prompt[1:])).read_text(encoding="utf-8")

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        sys.exit("ERROR: GEMINI_API_KEY not set. Use the gen.sh wrapper or export it first.")

    try:
        from google import genai
        from google.genai import types
    except ImportError:
        sys.exit("ERROR: google-genai not installed. Run: pip install google-genai pillow")

    refs = load_refs(args.templates_dir, args.max_refs)
    if not refs:
        print(f"[warn] no reference images found in {args.templates_dir}", file=sys.stderr)

    client = genai.Client(api_key=api_key)

    contents = [prompt]
    for f in refs:
        contents.append(types.Part.from_bytes(data=Path(f).read_bytes(), mime_type=mime_for(f)))

    # Config is built defensively: image_config field names have shifted across
    # SDK versions, so we degrade gracefully. The prompt itself also states 16:9,
    # so even a minimal config still yields a horizontal image.
    def build_config(level):
        if level == 0:
            return types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio=args.aspect_ratio, image_size=args.resolution
                ),
            )
        if level == 1:
            return types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(aspect_ratio=args.aspect_ratio),
            )
        return types.GenerateContentConfig(response_modalities=["TEXT", "IMAGE"])

    resp = None
    last_err = None
    for level in (0, 1, 2):
        try:
            resp = client.models.generate_content(
                model=args.model, contents=contents, config=build_config(level)
            )
            break
        except Exception as e:  # noqa: BLE001 - retry with simpler config
            last_err = e
            print(f"[warn] config level {level} failed: {e}", file=sys.stderr)
    if resp is None:
        sys.exit(f"ERROR: generation failed: {last_err}")

    out = Path(os.path.expanduser(args.out))
    out.parent.mkdir(parents=True, exist_ok=True)

    saved = False
    notes = []
    for part in resp.candidates[0].content.parts:
        if getattr(part, "inline_data", None) is not None and part.inline_data.data:
            out.write_bytes(part.inline_data.data)
            saved = True
        elif getattr(part, "text", None):
            notes.append(part.text)

    if not saved:
        sys.exit(f"ERROR: no image in response. Model said: {' '.join(notes) or '(nothing)'}")

    print(f"Saved: {out}")
    print(f"Refs used: {len(refs)} ({', '.join(Path(r).name for r in refs)})")
    if notes:
        print("Model note:", " ".join(notes).strip()[:500])


if __name__ == "__main__":
    main()
