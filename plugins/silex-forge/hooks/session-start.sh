#!/usr/bin/env bash
# SessionStart — injecte un rappel si forge.config locale absente/incomplète.
# Sortie: JSON hookSpecificOutput.additionalContext (jamais bloquant).
set -euo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$ROOT" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

LIB="$ROOT/scripts/lib"
export PYTHONPATH="$LIB${PYTHONPATH:+:$PYTHONPATH}"

if ! command -v python3 >/dev/null 2>&1; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "silex-forge: python3 manquant — impossible de vérifier forge.config. Installe python3 puis relance, ou run skill forge-setup."
  }
}
EOF
  exit 0
fi

python3 - <<'PY'
import json
from load_config import doctor, LOCAL_PATH

d = doctor()
if d.get("ok"):
    art = d.get("artifacts_root") or "?"
    hub = d.get("hub_root") or "?"
    msg = (
        "silex-forge config OK.\n"
        f"- hub_root: {hub}\n"
        f"- artifacts: {art}\n"
        f"- config: {d.get('config_source')}\n"
        "SSOT artefacts HTML = hub (artifacts/). "
        "Deploy live = git silex-forge site/a/ via forge-publish."
    )
    if d.get("warnings"):
        msg += "\nWarnings: " + "; ".join(d["warnings"])
else:
    issues = "; ".join(d.get("issues") or ["config incomplete"])
    msg = (
        "silex-forge config MANQUANTE ou INCOMPLÈTE.\n"
        f"Issues: {issues}\n"
        f"Local attendu: {LOCAL_PATH}\n"
        f"Example: {d.get('example_path')}\n"
        "ACTION OBLIGATOIRE avant publish / write artefact: lancer le skill "
        "**forge-setup** (setup + doctor). Ne pas inventer un hub_root — "
        "demander le path absolu silex-hub de l'opérateur "
        "(diffère entre Mickael / Pierre / Armand)."
    )

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": msg,
    }
}, ensure_ascii=False))
PY
