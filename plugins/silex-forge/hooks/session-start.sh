#!/usr/bin/env bash
# SessionStart — remind if local forge.config is missing/incomplete.
# Output: JSON hookSpecificOutput.additionalContext (never blocking).
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
    "additionalContext": "silex-forge: python3 missing — cannot verify forge.config. Install python3, or run skill forge-setup."
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
        "SSOT HTML = hub artifacts/. "
        "Live deploy = wrangler pages deploy (forge.env); HTML is not in git."
    )
    if d.get("warnings"):
        msg += "\nWarnings: " + "; ".join(d["warnings"])
else:
    issues = "; ".join(d.get("issues") or ["config incomplete"])
    msg = (
        "silex-forge config MISSING or INCOMPLETE.\n"
        f"Issues: {issues}\n"
        f"Expected local file: {LOCAL_PATH}\n"
        f"Example: {d.get('example_path')}\n"
        "REQUIRED before publish / writing an artifact: run skill "
        "**forge-setup**. Do not invent hub_root — ask the operator "
        "for their absolute silex-hub path (varies per machine)."
    )

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": msg,
    }
}))
PY
