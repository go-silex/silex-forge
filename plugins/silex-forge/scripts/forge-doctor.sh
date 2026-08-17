#!/usr/bin/env bash
# forge-doctor.sh — vérifie config forge (locale + complète) ; exit 1 si KO
#
#   forge-doctor.sh           # rapport humain
#   forge-doctor.sh --json    # JSON only
#   forge-doctor.sh --quiet   # exit code only
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
export PYTHONPATH="$LIB_DIR${PYTHONPATH:+:$PYTHONPATH}"

die() { echo "✗ $*" >&2; exit 1; }

JSON_ONLY=0
QUIET=0
for a in "$@"; do
  case "$a" in
    --json|-j) JSON_ONLY=1 ;;
    --quiet|-q) QUIET=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: forge-doctor.sh [--json] [--quiet]
  Vérifie ~/.config/silex/forge.config.json (fallback example).
  Si KO → lancer le skill forge-setup.
EOF
      exit 0
      ;;
  esac
done

[ -d "$LIB_DIR" ] || die "lib manquante: $LIB_DIR"
command -v python3 >/dev/null || die "python3 requis"

if [ "$JSON_ONLY" -eq 1 ]; then
  python3 - <<'PY'
import json, sys
from load_config import doctor
d = doctor()
print(json.dumps(d, ensure_ascii=False, indent=2))
sys.exit(0 if d["ok"] else 1)
PY
fi

if [ "$QUIET" -eq 1 ]; then
  python3 - <<'PY'
import sys
from load_config import doctor
sys.exit(0 if doctor()["ok"] else 1)
PY
fi

python3 - <<'PY'
import sys
from load_config import doctor

d = doctor()
print("silex-forge · doctor")
print(f"  source   : {d.get('config_source')}")
print(f"  fallback : {d.get('fallback')}")
print(f"  hub_root : {d.get('hub_root') or '—'}")
print(f"  artifacts: {d.get('artifacts_root') or '—'}")
acct = d.get("cloudflare_account_id") or ""
acct_s = f"{acct[:8]}…" if len(acct) > 8 else (acct or "—")
print(f"  pages    : {d.get('pages_project') or 'silex-forge'}")
print(f"  cf acct  : {acct_s}")
print(f"  cf token : {'OK' if d.get('has_token') else 'absent (publish KO)'}")
print(f"  deploy   : {'OK' if d.get('deploy_ready') else 'KO'}")
if d.get("ok"):
    print("  status   : OK")
    for w in d.get("warnings") or []:
        print(f"  ⚠ {w}")
    sys.exit(0)
print("  status   : KO")
for i in d.get("issues") or []:
    print(f"  ✗ {i}")
for w in d.get("warnings") or []:
    print(f"  ⚠ {w}")
print()
print("→ Lance le skill forge-setup pour créer/compléter la config locale.")
print(f"  local attendu : {d.get('local_path')}")
print(f"  example       : {d.get('example_path')}")
sys.exit(1)
PY
