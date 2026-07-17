#!/usr/bin/env bash
# publish.sh — publie un artefact HTML sur forge.gosilex.com
#
#   publish.sh <slug> <path> [options]
#   publish.sh --share <slug>              # génère/rafraîchit un lien share (clé)
#   publish.sh --unshare <slug>            # révoque le lien share
#   publish.sh --list | --remove <slug> | --rebuild-index
#
# Modèle d'accès (v2) :
#   /a/<slug>/              INTERNE — Cloudflare Access (équipe) — listé au catalogue
#   /s/<slug>/<key>/        SHARE  — Bypass Access, clé haute-entropie dans le path
#                           → PAS listé sur la landing
#   ?k=                     même secret (pour coller au pattern 1page) ; le path
#                           /s/.../<key>/ est la garde réelle côté Access
#
# Options publish :
#   --title T  --type TYPE  --desc D
#   --share    crée aussi un lien share + barre « Partager » + shortlink si possible
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_REPO="${FORGE_REPO:-git@github.com:go-silex/silex-forge.git}"
PUBLIC_HOST="${PUBLIC_HOST:-forge.gosilex.com}"
SHLINK_DOMAIN="${SHLINK_DOMAIN:-s.gosilex.com}"

die()  { echo "✗ $*" >&2; exit 1; }
info() { echo "▸ $*"; }
warn() { echo "  ⚠ $*" >&2; }
ok()   { echo "✓ $*"; }

GIT() { git -c core.hooksPath=/dev/null "$@"; }

WORK=""
cleanup() { [ -n "${WORK:-}" ] && rm -rf "$WORK"; }
trap cleanup EXIT

usage() {
  cat <<EOF
Usage:
  publish.sh <slug> <path> [--share] [--title T] [--type TYPE] [--desc D]
  publish.sh --share <slug>       # mint/refresh share link for existing slug
  publish.sh --unshare <slug>
  publish.sh --list | --remove <slug> | --rebuild-index

  Interne  : https://forge.gosilex.com/a/<slug>/     (Access, catalogue)
  Share    : https://forge.gosilex.com/s/<slug>/<key>/  (public, unlisted)
EOF
}

validate_slug() {
  local s="${1-}"
  case "$s" in
    '' )            die "slug vide" ;;
    */*|*..*|.|.. ) die "slug invalide (path): '$s'" ;;
  esac
  [[ "$s" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "slug invalide: '$s'"
  case "$s" in
    index|404|robots|registry|site|a|p|s|images|public|_headers) die "slug réservé: '$s'" ;;
  esac
}

whoami_id() { git config user.email 2>/dev/null || echo "${USER:-inconnu}@$(hostname)"; }

clone_repo() {
  WORK="$(mktemp -d)"
  info "clone $FORGE_REPO"
  GIT clone --depth 1 --branch main --quiet "$FORGE_REPO" "$WORK/repo" \
    || die "clone impossible — branche main ? accès GitHub ?"
  [ -d "$WORK/repo/site" ] || die "repo sans site/"
  [ -f "$WORK/repo/site/404.html" ] || die "site/404.html manquant"
}

commit_push() {
  local msg="$1"
  cd "$WORK/repo"
  GIT add -A
  if GIT diff --cached --quiet; then
    info "rien à publier (contenu identique)"
    return 1
  fi
  GIT -c user.email="$(whoami_id)" -c user.name="silex-forge" commit -q -m "$msg"
  local i
  for i in 1 2 3 4 5; do
    GIT push --quiet origin HEAD:main 2>/dev/null && return 0
    warn "push rejeté — rebase $i/5"
    GIT fetch --quiet origin main || die "fetch impossible"
    GIT rebase --quiet origin/main || die "rebase conflit — relance"
  done
  die "push rejeté 5×"
}

gen_index() {
  python3 "$WORK/repo/plugins/silex-forge/scripts/gen-index.py" \
    || die "gen-index.py a échoué"
}

mint_key() {
  # url-safe ~24 chars
  python3 -c "import secrets; print(secrets.token_urlsafe(18))"
}

write_registry_json() {
  # env: SLUG TITLE TYPE DESC DAY PATH SHARE_KEY SHARE_PATH LIST_ON_INDEX SHORT_URL
  python3 - <<'PY'
import json, os
data = {
  "slug": os.environ["SLUG"],
  "title": os.environ["TITLE"],
  "description": os.environ.get("DESC", ""),
  "type": os.environ.get("TYP", "html"),
  "date": os.environ["DAY"],
  "path": os.environ["PATHU"],
  "list_on_index": os.environ.get("LIST_ON_INDEX", "true").lower() == "true",
  "visibility": "internal",
}
if os.environ.get("SHARE_KEY"):
  data["share_key"] = os.environ["SHARE_KEY"]
  data["share_path"] = os.environ["SHARE_PATH"]
  data["share_url"] = f"https://{os.environ['PUBLIC_HOST']}{os.environ['SHARE_PATH']}"
  if os.environ.get("SHORT_URL"):
    data["short_url"] = os.environ["SHORT_URL"]
path = os.environ["OUT"]
open(path, "w", encoding="utf-8").write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
print("registry", path)
PY
}

maybe_shortlink() {
  local long_url="$1" slug="$2"
  local short_slug="f-${slug}"
  if ! command -v shlink &>/dev/null; then
    warn "shlink CLI absent — pas de shortlink auto"
    return 1
  fi
  if shlink short -- "$long_url" "$short_slug" 2>/dev/null; then
    echo "https://${SHLINK_DOMAIN}/${short_slug}"
    return 0
  fi
  # slug taken — random suffix
  local r
  r=$(python3 -c "import secrets; print(secrets.token_hex(2))")
  if shlink short -- "$long_url" "${short_slug}-${r}" 2>/dev/null; then
    echo "https://${SHLINK_DOMAIN}/${short_slug}-${r}"
    return 0
  fi
  warn "shlink a échoué"
  return 1
}

resolve_source() {
  local input="$1"
  [ -e "$input" ] || die "source introuvable: $input"
  if [ -f "$input" ]; then
    case "$input" in *.html|*.htm) ;; *) die "fichier .html attendu" ;; esac
    STAGE="$WORK/src"
    mkdir -p "$STAGE"
    cp -f "$input" "$STAGE/index.html"
    SRC_DIR="$STAGE"
  elif [ -d "$input" ]; then
    [ -f "$input/index.html" ] || die "dossier sans index.html"
    SRC_DIR="$input"
  else
    die "source invalide"
  fi
}

create_share_from_internal() {
  local slug="$1"
  local key share_path share_url short_url dest src
  key=$(mint_key)
  share_path="/s/${slug}/${key}/"
  share_url="https://${PUBLIC_HOST}${share_path}"
  src="$WORK/repo/site/a/${slug}"
  [ -d "$src" ] || die "artefact interne absent: /a/${slug}/ — publie d'abord"
  # drop old share trees for this slug
  rm -rf "$WORK/repo/site/s/${slug}"
  dest="$WORK/repo/site/s/${slug}/${key}"
  mkdir -p "$dest"
  cp -a "$src"/. "$dest"/
  # strip team-only share bar from public copy? keep copy button harmless
  date -u +%Y%m%dT%H%M%SZ > "$dest/build-id.txt"

  short_url=""
  if su=$(maybe_shortlink "$share_url" "$slug"); then
    short_url="$su"
  fi

  # update registry
  local reg="$WORK/repo/registry/${slug}.json"
  [ -f "$reg" ] || die "registry manquant pour $slug"
  SHARE_KEY="$key" SHARE_PATH="$share_path" SHORT_URL="$short_url" PUBLIC_HOST="$PUBLIC_HOST" \
  python3 - "$reg" <<'PY'
import json, os, sys
path = sys.argv[1]
d = json.load(open(path, encoding="utf-8"))
d["share_key"] = os.environ["SHARE_KEY"]
d["share_path"] = os.environ["SHARE_PATH"]
d["share_url"] = f"https://{os.environ['PUBLIC_HOST']}{os.environ['SHARE_PATH']}"
if os.environ.get("SHORT_URL"):
  d["short_url"] = os.environ["SHORT_URL"]
# never list share-only; keep list_on_index for the internal card
d.setdefault("list_on_index", True)
json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(path, "a", encoding="utf-8").write("\n")
print(d["share_url"])
PY

  # inject bar into INTERNAL copy (team can re-copy)
  python3 "$WORK/repo/plugins/silex-forge/scripts/inject-share-bar.py" \
    "$src/index.html" \
    --slug "$slug" \
    --share-url "$share_url" \
    ${short_url:+--short-url "$short_url"} || true

  # also inject into share copy with same URLs
  python3 "$WORK/repo/plugins/silex-forge/scripts/inject-share-bar.py" \
    "$dest/index.html" \
    --slug "$slug" \
    --share-url "$share_url" \
    ${short_url:+--short-url "$short_url"} || true

  echo "$share_url"
}

cmd_list() {
  clone_repo
  info "artefacts ($PUBLIC_HOST)"
  (
    cd "$WORK/repo"
    for f in registry/*.json; do
      [ -f "$f" ] || continue
      python3 -c "
import json
d=json.load(open('$f'))
share='share' if d.get('share_key') else '     '
listed='catalog' if d.get('list_on_index', True) else 'hidden '
print(f\"  {listed:7} {share:5}  {d.get('path','?'):28}  {d.get('title','')}\")
if d.get('share_url'):
  print(f\"           share → {d['share_url']}\")
"
    done
  )
}

cmd_remove() {
  local slug="$1"
  validate_slug "$slug"
  clone_repo
  rm -rf "$WORK/repo/site/a/$slug" "$WORK/repo/site/p/$slug" "$WORK/repo/site/s/$slug"
  rm -f "$WORK/repo/registry/${slug}.json"
  gen_index
  if commit_push "chore(forge): remove $slug"; then
    ok "retiré"
  fi
}

cmd_unshare() {
  local slug="$1"
  validate_slug "$slug"
  clone_repo
  rm -rf "$WORK/repo/site/s/$slug"
  local reg="$WORK/repo/registry/${slug}.json"
  [ -f "$reg" ] || die "inconnu: $slug"
  python3 - "$reg" <<'PY'
import json, sys
p=sys.argv[1]
d=json.load(open(p, encoding="utf-8"))
for k in ("share_key","share_path","share_url","short_url"):
  d.pop(k, None)
json.dump(d, open(p,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
open(p,"a",encoding="utf-8").write("\n")
PY
  gen_index
  if commit_push "chore(forge): unshare $slug"; then
    ok "share révoqué pour $slug"
  fi
}

cmd_share_only() {
  local slug="$1"
  validate_slug "$slug"
  clone_repo
  local url
  url=$(create_share_from_internal "$slug")
  gen_index
  if commit_push "feat(forge): share $slug"; then
    ok "share mint"
    echo "  URL:   $url"
    echo "  (non listé sur la landing — Access bypass /s/*)"
  fi
}

cmd_rebuild_index() {
  clone_repo
  gen_index
  if commit_push "chore(forge): rebuild index"; then
    ok "index regénéré"
  fi
}

cmd_publish() {
  local slug="$1" source="$2"
  shift 2
  local do_share=false title="" typ="html" desc=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --share)  do_share=true; shift ;;
      --public) die "--public retiré. Utilise --share (lien à clé, non listé)." ;;
      --title)  title="${2-}"; shift 2 ;;
      --type)   typ="${2-}"; shift 2 ;;
      --desc)   desc="${2-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "option inconnue: $1" ;;
    esac
  done
  validate_slug "$slug"
  [ -n "$title" ] || title="$slug"

  clone_repo
  resolve_source "$source"

  local dest path_url
  path_url="/a/${slug}/"
  dest="$WORK/repo/site/a/${slug}"
  mkdir -p "$dest"
  cp -a "$SRC_DIR"/. "$dest"/
  [ -f "$dest/index.html" ] || die "index.html manquant"
  date -u +%Y%m%dT%H%M%SZ > "$dest/build-id.txt"

  # registry base
  export SLUG="$slug" TITLE="$title" TYP="$typ" DESC="$desc" DAY="$(date -u +%Y-%m-%d)"
  export PATHU="$path_url" LIST_ON_INDEX="true" OUT="$WORK/repo/registry/${slug}.json"
  export PUBLIC_HOST="$PUBLIC_HOST" SHARE_KEY="" SHARE_PATH="" SHORT_URL=""
  write_registry_json

  local share_url=""
  if $do_share; then
    share_url=$(create_share_from_internal "$slug")
  fi

  gen_index
  if commit_push "feat(forge): publish $slug$($do_share && echo ' +share')"; then
    ok "publié"
    echo "  Interne: https://${PUBLIC_HOST}${path_url}  (Access)"
    if [ -n "$share_url" ]; then
      echo "  Share:   $share_url  (public, unlisted)"
    fi
  fi
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1-}" in
  ""|-h|--help) usage; exit 0 ;;
  --list) cmd_list ;;
  --remove)
    [ -n "${2-}" ] || die "usage: --remove <slug>"
    cmd_remove "$2"
    ;;
  --unshare)
    [ -n "${2-}" ] || die "usage: --unshare <slug>"
    cmd_unshare "$2"
    ;;
  --rebuild-index) cmd_rebuild_index ;;
  --share)
    # --share <slug> alone = mint share for existing
    if [ -n "${2-}" ] && [ -z "${3-}" ]; then
      cmd_share_only "$2"
    else
      die "usage: --share <slug>   ou   publish.sh <slug> <path> --share"
    fi
    ;;
  *)
    [ -n "${2-}" ] || { usage; exit 1; }
    cmd_publish "$@"
    ;;
esac
