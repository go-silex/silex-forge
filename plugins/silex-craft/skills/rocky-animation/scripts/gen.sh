#!/usr/bin/env bash
# Portable wrapper. Works whether the skill lives in a personal dir
# (~/.claude/skills/...) or in the shared silex-hub vault (.claude/skills/...).
#
# - Creates/reuses a MACHINE-LOCAL Python venv outside any synced vault
#   (default: ~/.cache/rocky-animation/venv), and auto-installs deps on first run.
# - Reads GEMINI_API_KEY from the environment, else from the macOS Keychain.
# All args are forwarded to generate_image.py.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # skill root

# Machine-local venv (NEVER inside the Drive-synced vault, so it doesn't sync
# and never conflicts between machines).
VENV="${ROCKY_VENV:-${XDG_CACHE_HOME:-$HOME/.cache}/rocky-animation/venv}"
PYBIN="$VENV/bin/python"

if [[ ! -x "$PYBIN" ]]; then
  echo "[rocky] première utilisation sur cette machine : installation de l'environnement Python…" >&2
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
  "$VENV/bin/pip" install --quiet -r "$DIR/scripts/requirements.txt"
elif ! "$PYBIN" -c "import google.genai" >/dev/null 2>&1; then
  "$VENV/bin/pip" install --quiet -r "$DIR/scripts/requirements.txt"
fi

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  if [[ -f "${HOME}/.config/silex/gemini-api-key" ]]; then
    GEMINI_API_KEY="$(tr -d '\n' < "${HOME}/.config/silex/gemini-api-key")"
  elif command -v security >/dev/null 2>&1; then
    GEMINI_API_KEY="$(security find-generic-password -s GEMINI_API_KEY -a gosilex -w 2>/dev/null || true)"
    if [[ -z "${GEMINI_API_KEY:-}" ]]; then
      GEMINI_API_KEY="$(security find-generic-password -s GEMINI_API_KEY -w 2>/dev/null || true)"
    fi
  fi
fi
export GEMINI_API_KEY

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  cat >&2 <<'MSG'
ERREUR : GEMINI_API_KEY introuvable.
Ajoute ta clé Gemini (Nano Banana Pro), au choix :
  • fichier machine : mkdir -p ~/.config/silex && echo 'TA_CLE' > ~/.config/silex/gemini-api-key && chmod 600 ~/.config/silex/gemini-api-key
  • variable d'env  : export GEMINI_API_KEY='TA_CLE'
  • Keychain macOS  : security add-generic-password -s GEMINI_API_KEY -a gosilex -w 'TA_CLE'
MSG
  exit 1
fi

exec "$PYBIN" "$DIR/scripts/generate_image.py" "$@"
