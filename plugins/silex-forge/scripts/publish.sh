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
LIB_DIR="$SCRIPT_DIR/lib"

# Caller env wins over config file
_ENV_FORGE_REPO="${FORGE_REPO-}"
_ENV_PUBLIC_HOST="${PUBLIC_HOST-}"
_ENV_SHLINK_DOMAIN="${SHLINK_DOMAIN-}"

# Config: ~/.config/silex/forge.config.json → fallback forge.config.example.json
if [ -f "$LIB_DIR/load_config.py" ] && command -v python3 >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  eval "$(PYTHONPATH="$LIB_DIR${PYTHONPATH:+:$PYTHONPATH}" python3 -c 'from load_config import export_env; print(export_env())')"
fi

FORGE_REPO="${_ENV_FORGE_REPO:-${FORGE_REPO:-git@github.com:go-silex/silex-forge.git}}"
PUBLIC_HOST="${_ENV_PUBLIC_HOST:-${FORGE_PUBLIC_HOST:-${PUBLIC_HOST:-forge.gosilex.com}}}"
SHLINK_DOMAIN="${_ENV_SHLINK_DOMAIN:-${FORGE_SHLINK_DOMAIN:-${SHLINK_DOMAIN:-s.gosilex.com}}}"
ARTIFACTS_ROOT="${FORGE_ARTIFACTS_ROOT:-}"
INTERNAL_PREFIX="${FORGE_INTERNAL_PREFIX:-a}"

die()  { echo "✗ $*" >&2; exit 1; }
info() { echo "▸ $*"; }
warn() { echo "  ⚠ $*" >&2; }
ok()   { echo "✓ $*"; }

require_forge_config() {
  if [ ! -f "$LIB_DIR/load_config.py" ]; then
    return 0
  fi
  if PYTHONPATH="$LIB_DIR${PYTHONPATH:+:$PYTHONPATH}" python3 -c \
    'from load_config import doctor; import sys; sys.exit(0 if doctor()["ok"] else 1)' 2>/dev/null; then
    return 0
  fi
  warn "forge config incomplete — run skill forge-setup"
  [ -n "${ARTIFACTS_ROOT:-}" ] || die "hub/artifacts non configurés. Lance forge-setup (doctor KO)."
}

# Sync published tree into hub SSOT (never secrets) + meta.json from registry
sync_to_hub_artifacts() {
  local slug="$1" src_dir="$2"
  [ -n "${ARTIFACTS_ROOT:-}" ] || { warn "ARTIFACTS_ROOT vide — skip sync hub"; return 0; }
  [ -d "$src_dir" ] || return 0
  local dest="${ARTIFACTS_ROOT}/${slug}"
  mkdir -p "$dest"
  cp -a "$src_dir"/. "$dest"/
  local reg="$WORK/repo/registry/${slug}.json"
  if [ -f "$reg" ]; then
    cp -f "$reg" "$dest/meta.json"
  fi
  ok "hub SSOT → $dest"
}

GIT() { git -c core.hooksPath=/dev/null "$@"; }

WORK=""
cleanup() { [ -n "${WORK:-}" ] && rm -rf "$WORK"; }
trap cleanup EXIT

usage() {
  cat <<EOF
Usage:
  publish.sh <slug> [path] [--share] [--title T] [--type TYPE] [--desc D]
  publish.sh --share <slug>       # mint/refresh share link for existing slug
  publish.sh --unshare <slug>
  publish.sh --list | --remove <slug> | --rebuild-index

  path omis → lit \$ARTIFACTS_ROOT/<slug>/ (hub SSOT, via forge.config)

  Interne  : https://${PUBLIC_HOST}/${INTERNAL_PREFIX}/<slug>/  (Access, catalogue)
  Share    : https://${PUBLIC_HOST}/s/<slug>/<key>/  (public, unlisted)
  Config   : ~/.config/silex/forge.config.json (fallback example)
  Doctor   : scripts/forge-doctor.sh · skill forge-setup
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

SCRIPTS() { echo "$WORK/repo/plugins/silex-forge/scripts"; }

gen_index() {
  python3 "$(SCRIPTS)/gen-index.py" \
    || die "gen-index.py a échoué"
}

# Chrome headless + ffmpeg → site/a/<slug>/og.jpg (pure sh, best-effort)
gen_og_images() {
  local slug="${1-}"
  local args=()
  [ -n "$slug" ] && args+=(--slug "$slug")
  local sh
  sh="$(SCRIPTS)/gen-og-images.sh"
  if [ ! -x "$sh" ]; then
    chmod +x "$sh" 2>/dev/null || true
  fi
  if [ -f "$sh" ]; then
    (cd "$WORK/repo" && bash "$sh" "${args[@]}") \
      && ok "og thumbs" || warn "gen-og-images skip/failed (publish continues)"
  else
    warn "gen-og-images.sh missing — skip thumbs"
  fi
}

# OG inject on internal index.html
inject_og_for_slug() {
  local slug="$1" title="$2" desc="$3" path_url="$4"
  local html="$WORK/repo/site/a/${slug}/index.html"
  [ -f "$html" ] || return 0
  local img_args=()
  local og_img=""
  if [ -f "$WORK/repo/site/a/${slug}/og.jpg" ]; then
    og_img="https://${PUBLIC_HOST}/a/${slug}/og.jpg"
  elif [ -f "$WORK/repo/site/a/${slug}/og.png" ]; then
    og_img="https://${PUBLIC_HOST}/a/${slug}/og.png"
  fi
  if [ -n "$og_img" ]; then
    img_args=(--image "$og_img")
  fi
  python3 "$(SCRIPTS)/inject-og.py" "$html" \
    --title "$title" \
    --description "${desc:-$title}" \
    --url "https://${PUBLIC_HOST}${path_url}" \
    "${img_args[@]}" \
    || die "inject-og failed"
  python3 "$(SCRIPTS)/verify-og.py" --file "$html" --expect-title "$title" \
    || die "verify-og (local) failed"
}

# Hub memory notes (Drive vault — best effort)
hub_index_update() {
  local slug="${1-}"
  local hub_args=(--registry "$WORK/repo/registry" --host "$PUBLIC_HOST")
  [ -n "$slug" ] && hub_args+=(--slug "$slug")
  if python3 "$(SCRIPTS)/hub-index.py" "${hub_args[@]}"; then
    ok "hub index mis à jour"
  else
    warn "hub-index a échoué (HUB_ROOT manquant ?) — publish git OK quand même"
  fi
}

# Local OG verify only — pages.dev is blocked (Access + middleware); do not probe open twin.
verify_og_live() {
  local slug="$1" title="$2"
  local html="$WORK/repo/site/a/${slug}/index.html"
  if [ -f "$html" ] && python3 "$(SCRIPTS)/verify-og.py" --file "$html" --expect-title "$title" 2>/dev/null; then
    ok "verify-og local OK"
    return 0
  fi
  warn "verify-og local skip/fail — check site/a/${slug}/index.html"
  return 0
}

# KV share helpers (SSOT = KV; never git secrets). Needs CF global key or token with KV edit.
kv_auth_ok() {
  { [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { [ -n "${CLOUDFLARE_API_KEY:-}" ] && [ -n "${CLOUDFLARE_EMAIL:-}" ]; }; }
}

kv_curl() {
  # usage: kv_curl METHOD path [curl body args...]
  local method="$1" path="$2"
  shift 2
  local acct="${CLOUDFLARE_ACCOUNT_ID:-f8026cffc9463a03e1a6a76af5301861}"
  local ns="${FORGE_SHARES_KV_ID:-758e41aec6964f2b9ef590c296ff7e20}"
  local url="https://api.cloudflare.com/client/v4/accounts/${acct}/storage/kv/namespaces/${ns}${path}"
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    curl -sS -X "$method" "$url" -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" "$@"
  else
    curl -sS -X "$method" "$url" \
      -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" "$@"
  fi
}

kv_put_share() {
  local slug="$1" key="$2"
  kv_auth_ok || return 1
  kv_curl PUT "/values/share:${slug}" -H "Content-Type: text/plain" --data "$key" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get("success") else 1)'
}

kv_delete_share() {
  local slug="$1"
  kv_auth_ok || return 1
  kv_curl DELETE "/values/share:${slug}" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get("success") else 1)'
}

mint_key() {
  # url-safe ~24 chars
  python3 -c "import secrets; print(secrets.token_urlsafe(18))"
}

write_registry_json() {
  # env: SLUG TITLE TYPE DESC DAY PATH LIST_ON_INDEX SHARED (bool snapshot, no secrets)
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
  "shared": os.environ.get("SHARED", "false").lower() == "true",
}
# Never write share_key / share_url / share_path into git
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
  # Mint capability into KV only. Never write keys to registry/HTML.
  local slug="$1"
  local key share_path share_url short_url src
  key=$(mint_key)
  share_path="/s/${slug}/${key}/"
  share_url="https://${PUBLIC_HOST}${share_path}"
  src="$WORK/repo/site/a/${slug}"
  [ -d "$src" ] || die "artefact interne absent: /a/${slug}/ — publie d'abord"

  if kv_put_share "$slug" "$key"; then
    info "KV share:${slug} seed OK"
  else
    die "KV seed failed — set CLOUDFLARE_API_TOKEN or CLOUDFLARE_EMAIL+CLOUDFLARE_API_KEY (share key never goes to git)"
  fi

  short_url=""
  if su=$(maybe_shortlink "$share_url" "$slug"); then
    short_url="$su"
  fi

  local reg="$WORK/repo/registry/${slug}.json"
  [ -f "$reg" ] || die "registry manquant pour $slug"
  python3 - "$reg" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path, encoding="utf-8"))
for k in ("share_key", "share_path", "share_url", "share_url_query", "short_url"):
  d.pop(k, None)
d["shared"] = True
d.setdefault("list_on_index", True)
json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(path, "a", encoding="utf-8").write("\n")
PY

  # Re-inject bar without secrets
  python3 "$(SCRIPTS)/inject-share-bar.py" "$src/index.html" --slug "$slug" || true

  if [ -n "$short_url" ]; then
    echo "$short_url"
  else
    echo "$share_url"
  fi
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
share='share' if d.get('shared') else '     '
listed='catalog' if d.get('list_on_index', True) else 'hidden '
print(f\"  {listed:7} {share:5}  {d.get('path','?'):28}  {d.get('title','')}\")
"
    done
  )
}

cmd_remove() {
  local slug="$1"
  validate_slug "$slug"
  clone_repo
  rm -rf "$WORK/repo/site/a/$slug" "$WORK/repo/site/s/$slug"
  rm -f "$WORK/repo/registry/${slug}.json"
  gen_index
  if commit_push "chore(forge): remove $slug"; then
    ok "retiré"
    # refresh catalogue only
    hub_index_update
  fi
}

cmd_unshare() {
  local slug="$1"
  validate_slug "$slug"
  clone_repo
  rm -rf "$WORK/repo/site/s/$slug"
  local reg="$WORK/repo/registry/${slug}.json"
  [ -f "$reg" ] || die "inconnu: $slug"
  if kv_delete_share "$slug"; then
    info "KV share:${slug} deleted"
  else
    warn "KV delete failed — set CF credentials; runtime share may still be active"
  fi
  python3 - "$reg" <<'PY'
import json, sys
p=sys.argv[1]
d=json.load(open(p, encoding="utf-8"))
for k in ("share_key","share_path","share_url","share_url_query","short_url"):
  d.pop(k, None)
d["shared"] = False
json.dump(d, open(p,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
open(p,"a",encoding="utf-8").write("\n")
PY
  # strip any baked shareUrl from HTML
  local html="$WORK/repo/site/a/${slug}/index.html"
  if [ -f "$html" ]; then
    python3 "$(SCRIPTS)/inject-share-bar.py" "$html" --slug "$slug" || true
  fi
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
    echo "  (non listé — KV + Function /s/*)"
    hub_index_update "$slug"
  fi
}

cmd_rebuild_index() {
  clone_repo
  gen_og_images   # all slugs, stale only
  gen_index
  if commit_push "chore(forge): rebuild index"; then
    ok "index regénéré"
    hub_index_update
  fi
}

cmd_publish() {
  local slug="$1"
  shift
  local source="" do_share=false title="" typ="html" desc=""
  # path is optional if hub artifacts/<slug>/ exists
  if [ $# -gt 0 ] && [[ "${1-}" != --* ]]; then
    source="$1"
    shift
  fi
  while [ $# -gt 0 ]; do
    case "$1" in
      --share)  do_share=true; shift ;;
      --public) die "--public et /p/ purgés. Utilise --share (lien /s/<slug>/<key>/)." ;;
      --title)  title="${2-}"; shift 2 ;;
      --type)   typ="${2-}"; shift 2 ;;
      --desc)   desc="${2-}"; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "option inconnue: $1" ;;
    esac
  done
  validate_slug "$slug"
  require_forge_config
  [ -n "$title" ] || title="$slug"

  if [ -z "$source" ]; then
    if [ -n "${ARTIFACTS_ROOT:-}" ] && [ -f "${ARTIFACTS_ROOT}/${slug}/index.html" ]; then
      source="${ARTIFACTS_ROOT}/${slug}"
      info "source hub SSOT: $source"
    else
      die "path manquant et pas de ${ARTIFACTS_ROOT:-<artifacts>}/${slug}/index.html — forge-setup ?"
    fi
  fi

  clone_repo
  resolve_source "$source"

  local dest path_url
  path_url="/${INTERNAL_PREFIX}/${slug}/"
  dest="$WORK/repo/site/${INTERNAL_PREFIX}/${slug}"
  mkdir -p "$dest"
  cp -a "$SRC_DIR"/. "$dest"/
  [ -f "$dest/index.html" ] || die "index.html manquant"
  date -u +%Y%m%dT%H%M%SZ > "$dest/build-id.txt"

  # registry base
  export SLUG="$slug" TITLE="$title" TYP="$typ" DESC="$desc" DAY="$(date -u +%Y-%m-%d)"
  export PATHU="$path_url" LIST_ON_INDEX="true" OUT="$WORK/repo/registry/${slug}.json"
  export PUBLIC_HOST="$PUBLIC_HOST" SHARED="false"
  write_registry_json

  # Thumbs then meta OG + share bar
  gen_og_images "$slug"
  inject_og_for_slug "$slug" "$title" "$desc" "$path_url"
  python3 "$(SCRIPTS)/inject-share-bar.py" "$dest/index.html" --slug "$slug" || true

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
      echo "  Query:   https://${PUBLIC_HOST}/s/${slug}/?k=…  (alias)"
    fi
    # Hub SSOT: keep vault copy in sync (source of truth for team)
    sync_to_hub_artifacts "$slug" "$dest"
    hub_index_update "$slug"
    verify_og_live "$slug" "$title"
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
      die "usage: --share <slug>   ou   publish.sh <slug> [path] --share"
    fi
    ;;
  *)
    [ -n "${1-}" ] || { usage; exit 1; }
    cmd_publish "$@"
    ;;
esac
