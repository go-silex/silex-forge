#!/usr/bin/env bash
# publish.sh — hub SSOT → build site → force-push branch cf-deploy → GH Action Pages
#
#   publish.sh <slug> [path] [options]
#   publish.sh --share <slug>
#   publish.sh --unshare <slug>
#   publish.sh --list | --remove <slug> | --rebuild-index
#
# Architecture:
#   SSOT     = $hub/$artifacts_dir/<slug>/  (silex-hub, rclone)
#   engine   = git main (plugins, functions, site skeleton)
#   deploy   = git branch cf-deploy (built site/ + functions/) → wrangler
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
DEPLOY_BRANCH="${FORGE_DEPLOY_BRANCH:-cf-deploy}"

_ENV_FORGE_REPO="${FORGE_REPO-}"
_ENV_PUBLIC_HOST="${PUBLIC_HOST-}"
_ENV_SHLINK_DOMAIN="${SHLINK_DOMAIN-}"

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

GIT() { git -c core.hooksPath=/dev/null "$@"; }

WORK=""
cleanup() { [ -n "${WORK:-}" ] && rm -rf "$WORK"; }
trap cleanup EXIT

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

usage() {
  cat <<EOF
Usage:
  publish.sh <slug> [path] [--share] [--title T] [--type TYPE] [--desc D]
  publish.sh --share <slug>
  publish.sh --unshare <slug>
  publish.sh --list | --remove <slug> | --rebuild-index

  SSOT   : \$ARTIFACTS_ROOT/<slug>/  (hub, forge.config)
  Deploy : branch ${DEPLOY_BRANCH} → GH Action → CF Pages
  Engine : main (plugins/functions — pas les HTML)

  Interne : https://${PUBLIC_HOST}/${INTERNAL_PREFIX}/<slug>/
  Share   : https://${PUBLIC_HOST}/s/<slug>/<key>/
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

clone_engine() {
  WORK="$(mktemp -d)"
  info "clone engine $FORGE_REPO (main)"
  GIT clone --depth 1 --branch main --quiet "$FORGE_REPO" "$WORK/repo" \
    || die "clone impossible — branche main ? accès GitHub ?"
  [ -d "$WORK/repo/site" ] || die "repo sans site/ skeleton"
  [ -f "$WORK/repo/site/404.html" ] || die "site/404.html manquant"
}

SCRIPTS() {
  # prefer scripts inside cloned engine (version matching deploy)
  if [ -n "${WORK:-}" ] && [ -d "$WORK/repo/plugins/silex-forge/scripts" ]; then
    echo "$WORK/repo/plugins/silex-forge/scripts"
  else
    echo "$SCRIPT_DIR"
  fi
}

# Build site/a + registry from hub into the engine clone
build_from_hub() {
  local build_py
  build_py="$(SCRIPTS)/build-site-from-hub.py"
  [ -f "$build_py" ] || build_py="$SCRIPT_DIR/build-site-from-hub.py"
  [ -f "$build_py" ] || die "build-site-from-hub.py manquant"
  info "build site from hub SSOT → $WORK/repo"
  PYTHONPATH="$(dirname "$build_py")/lib${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$build_py" --repo-root "$WORK/repo" \
    || die "build-site-from-hub failed"
}

# Force-push built payload to cf-deploy (transport only — not SSOT)
push_cf_deploy() {
  local msg="$1"
  cd "$WORK/repo"
  # Deploy payload: site + functions + wrangler + registry
  # + workflow file (GitHub loads workflows FROM the branch that receives the push)
  GIT checkout --orphan "cf-deploy-build-$$" >/dev/null 2>&1
  GIT reset -q
  GIT add -f site functions wrangler.toml registry \
    .github/workflows/deploy-pages.yml 2>/dev/null || {
    GIT add site functions wrangler.toml
    [ -d registry ] && GIT add registry
    [ -f .github/workflows/deploy-pages.yml ] && GIT add .github/workflows/deploy-pages.yml
  }
  if GIT diff --cached --quiet 2>/dev/null; then
    info "rien à déployer (payload identique?)"
    return 1
  fi
  GIT -c user.email="$(whoami_id)" -c user.name="silex-forge" commit -q -m "$msg"
  local i
  for i in 1 2 3 4 5; do
    if GIT push --force --quiet origin "HEAD:${DEPLOY_BRANCH}" 2>/dev/null; then
      ok "push ${DEPLOY_BRANCH}"
      # Trigger deploy from main (loads workflow reliably; overlays site from cf-deploy).
      # Push-to-cf-deploy alone may not run Actions if branch filters/orphan edge cases.
      if command -v gh >/dev/null 2>&1; then
        if gh workflow run "Deploy Pages" --repo go-silex/silex-forge --ref main 2>/dev/null; then
          ok "GH workflow_dispatch Deploy Pages (main + overlay cf-deploy)"
        else
          warn "gh workflow_dispatch failed — open Actions tab or: gh workflow run 'Deploy Pages' --ref main"
        fi
      else
        warn "install gh CLI to auto-trigger deploy, or run: gh workflow run 'Deploy Pages' --ref main"
      fi
      return 0
    fi
    warn "push ${DEPLOY_BRANCH} rejeté — retry $i/5"
    sleep 2
  done
  die "push ${DEPLOY_BRANCH} rejeté 5×"
}

write_hub_meta() {
  # env: SLUG TITLE TYP DESC DAY SHARED OUT INTERNAL_PREFIX
  [ -n "${ARTIFACTS_ROOT:-}" ] || return 0
  mkdir -p "${ARTIFACTS_ROOT}/${SLUG}"
  python3 - <<'PY'
import json, os
from pathlib import Path
slug = os.environ["SLUG"]
prefix = os.environ.get("INTERNAL_PREFIX", "a")
p = Path(os.environ["OUT"])
old = {}
if p.is_file():
    try:
        old = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        old = {}
shared = bool(old.get("shared"))
if os.environ.get("SHARED", "") != "":
    shared = os.environ["SHARED"].lower() == "true"
data = {
  "slug": slug,
  "title": os.environ.get("TITLE") or slug,
  "description": os.environ.get("DESC", ""),
  "type": os.environ.get("TYP", "html"),
  "date": os.environ.get("DAY", ""),
  "path": f"/{prefix}/{slug}/",
  "list_on_index": True,
  "visibility": "internal",
  "shared": shared,
}
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("hub meta", p)
PY
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

write_source_to_hub() {
  local slug="$1"
  [ -n "${ARTIFACTS_ROOT:-}" ] || die "ARTIFACTS_ROOT vide"
  local dest="${ARTIFACTS_ROOT}/${slug}"
  mkdir -p "$dest"
  # if source is already the hub dir, skip wipe
  if [ "$(cd "$SRC_DIR" && pwd)" = "$(cd "$dest" 2>/dev/null && pwd)" ]; then
    info "source = hub SSOT (in-place)"
    return 0
  fi
  # replace content but keep meta until write_hub_meta
  find "$dest" -mindepth 1 -maxdepth 1 ! -name 'meta.json' -exec rm -rf {} +
  cp -a "$SRC_DIR"/. "$dest"/
  date -u +%Y%m%dT%H%M%SZ > "$dest/build-id.txt"
  ok "hub SSOT ← $dest"
}

gen_og_images() {
  local slug="${1-}"
  local args=()
  [ -n "$slug" ] && args+=(--slug "$slug")
  local sh
  sh="$(SCRIPTS)/gen-og-images.sh"
  if [ -f "$sh" ]; then
    (cd "$WORK/repo" && bash "$sh" "${args[@]}") \
      && ok "og thumbs" || warn "gen-og-images skip/failed (publish continues)"
  fi
}

inject_og_for_slug() {
  local slug="$1" title="$2" desc="$3" path_url="$4"
  local html="$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/index.html"
  [ -f "$html" ] || return 0
  local img_args=() og_img=""
  if [ -f "$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/og.jpg" ]; then
    og_img="https://${PUBLIC_HOST}/${INTERNAL_PREFIX}/${slug}/og.jpg"
  elif [ -f "$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/og.png" ]; then
    og_img="https://${PUBLIC_HOST}/${INTERNAL_PREFIX}/${slug}/og.png"
  fi
  [ -n "$og_img" ] && img_args=(--image "$og_img")
  python3 "$(SCRIPTS)/inject-og.py" "$html" \
    --title "$title" \
    --description "${desc:-$title}" \
    --url "https://${PUBLIC_HOST}${path_url}" \
    "${img_args[@]}" \
    || die "inject-og failed"
  # write enhanced HTML back to hub SSOT
  if [ -n "${ARTIFACTS_ROOT:-}" ] && [ -d "${ARTIFACTS_ROOT}/${slug}" ]; then
    cp -f "$html" "${ARTIFACTS_ROOT}/${slug}/index.html"
    [ -f "$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/og.jpg" ] \
      && cp -f "$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/og.jpg" "${ARTIFACTS_ROOT}/${slug}/og.jpg" || true
  fi
}

hub_index_update() {
  local slug="${1-}"
  local reg="$WORK/repo/registry"
  [ -d "$reg" ] || return 0
  local hub_args=(--registry "$reg" --host "$PUBLIC_HOST")
  [ -n "$slug" ] && hub_args+=(--slug "$slug")
  if python3 "$(SCRIPTS)/hub-index.py" "${hub_args[@]}"; then
    ok "hub index notes"
  else
    warn "hub-index skip"
  fi
}

kv_auth_ok() {
  { [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { [ -n "${CLOUDFLARE_API_KEY:-}" ] && [ -n "${CLOUDFLARE_EMAIL:-}" ]; }; }
}

kv_curl() {
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
  python3 -c "import secrets; print(secrets.token_urlsafe(18))"
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
  local r
  r=$(python3 -c "import secrets; print(secrets.token_hex(2))")
  if shlink short -- "$long_url" "${short_slug}-${r}" 2>/dev/null; then
    echo "https://${SHLINK_DOMAIN}/${short_slug}-${r}"
    return 0
  fi
  return 1
}

set_hub_shared() {
  local slug="$1" shared="$2"
  local meta="${ARTIFACTS_ROOT}/${slug}/meta.json"
  [ -f "$meta" ] || return 0
  python3 - "$meta" "$shared" <<'PY'
import json, sys
p, shared = sys.argv[1], sys.argv[2].lower() == "true"
d = json.load(open(p, encoding="utf-8"))
for k in ("share_key", "share_path", "share_url", "share_url_query", "short_url"):
    d.pop(k, None)
d["shared"] = shared
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
}

create_share_kv() {
  local slug="$1"
  local key share_path share_url short_url
  key=$(mint_key)
  share_path="/s/${slug}/${key}/"
  share_url="https://${PUBLIC_HOST}${share_path}"
  [ -d "${ARTIFACTS_ROOT}/${slug}" ] || die "artefact hub absent: $slug"

  if kv_put_share "$slug" "$key"; then
    info "KV share:${slug} seed OK"
  else
    die "KV seed failed — set CLOUDFLARE_API_TOKEN (share key never goes to git/hub)"
  fi
  set_hub_shared "$slug" true
  short_url=""
  if su=$(maybe_shortlink "$share_url" "$slug"); then
    short_url="$su"
  fi
  if [ -n "$short_url" ]; then
    echo "$short_url"
  else
    echo "$share_url"
  fi
}

cmd_list() {
  require_forge_config
  info "artefacts hub SSOT ($PUBLIC_HOST)"
  if [ -z "${ARTIFACTS_ROOT:-}" ] || [ ! -d "$ARTIFACTS_ROOT" ]; then
    die "ARTIFACTS_ROOT manquant — forge-setup"
  fi
  local d
  for d in "$ARTIFACTS_ROOT"/*/; do
    [ -d "$d" ] || continue
    [ -f "${d}index.html" ] || continue
    python3 - "$d" <<'PY'
import json, sys
from pathlib import Path
d = Path(sys.argv[1])
meta = d / "meta.json"
title = d.name
shared = False
typ = "html"
if meta.is_file():
    try:
        m = json.loads(meta.read_text(encoding="utf-8"))
        title = m.get("title") or title
        shared = bool(m.get("shared"))
        typ = m.get("type") or typ
    except Exception:
        pass
flag = "share" if shared else "     "
print(f"  catalog {flag:5}  /a/{d.name:28}  [{typ}] {title}")
PY
  done
}

cmd_remove() {
  local slug="$1"
  validate_slug "$slug"
  require_forge_config
  [ -n "${ARTIFACTS_ROOT:-}" ] || die "ARTIFACTS_ROOT manquant"
  rm -rf "${ARTIFACTS_ROOT}/${slug}"
  ok "retiré du hub SSOT: $slug"
  clone_engine
  build_from_hub
  if push_cf_deploy "chore(forge): remove $slug"; then
    hub_index_update
  fi
}

cmd_unshare() {
  local slug="$1"
  validate_slug "$slug"
  require_forge_config
  if kv_delete_share "$slug"; then
    info "KV share:${slug} deleted"
  else
    warn "KV delete failed — set CF credentials"
  fi
  set_hub_shared "$slug" false
  clone_engine
  build_from_hub
  local html="$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/index.html"
  if [ -f "$html" ]; then
    python3 "$(SCRIPTS)/inject-share-bar.py" "$html" --slug "$slug" || true
    [ -n "${ARTIFACTS_ROOT:-}" ] && cp -f "$html" "${ARTIFACTS_ROOT}/${slug}/index.html" || true
  fi
  push_cf_deploy "chore(forge): unshare $slug" || true
  ok "share révoqué pour $slug"
}

cmd_share_only() {
  local slug="$1"
  validate_slug "$slug"
  require_forge_config
  local url
  url=$(create_share_kv "$slug")
  clone_engine
  build_from_hub
  local html="$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/index.html"
  if [ -f "$html" ]; then
    python3 "$(SCRIPTS)/inject-share-bar.py" "$html" --slug "$slug" || true
    cp -f "$html" "${ARTIFACTS_ROOT}/${slug}/index.html" || true
  fi
  if push_cf_deploy "feat(forge): share $slug"; then
    ok "share mint"
    echo "  URL:   $url"
    hub_index_update "$slug"
  fi
}

cmd_rebuild_index() {
  require_forge_config
  clone_engine
  build_from_hub
  gen_og_images
  # rebuild again to pick og files into hub? og written to site then copy back
  if [ -n "${ARTIFACTS_ROOT:-}" ]; then
    local s
    for s in "$WORK/repo/site/${INTERNAL_PREFIX}"/*/; do
      [ -d "$s" ] || continue
      local slug
      slug=$(basename "$s")
      [ -f "${s}og.jpg" ] && cp -f "${s}og.jpg" "${ARTIFACTS_ROOT}/${slug}/og.jpg" || true
    done
  fi
  build_from_hub
  if push_cf_deploy "chore(forge): rebuild index from hub"; then
    ok "index regénéré + cf-deploy"
    hub_index_update
  fi
}

cmd_publish() {
  local slug="$1"
  shift
  local source="" do_share=false title="" typ="html" desc=""
  if [ $# -gt 0 ] && [[ "${1-}" != --* ]]; then
    source="$1"
    shift
  fi
  while [ $# -gt 0 ]; do
    case "$1" in
      --share)  do_share=true; shift ;;
      --public) die "--public et /p/ purgés. Utilise --share." ;;
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

  # resolve source → always land in hub first
  if [ -z "$source" ]; then
    if [ -n "${ARTIFACTS_ROOT:-}" ] && [ -f "${ARTIFACTS_ROOT}/${slug}/index.html" ]; then
      source="${ARTIFACTS_ROOT}/${slug}"
      info "source hub SSOT: $source"
    else
      die "path manquant et pas de ${ARTIFACTS_ROOT:-<artifacts>}/${slug}/index.html"
    fi
  fi

  WORK="$(mktemp -d)"
  resolve_source "$source"
  write_source_to_hub "$slug"

  export SLUG="$slug" TITLE="$title" TYP="$typ" DESC="$desc" DAY="$(date -u +%Y-%m-%d)"
  export INTERNAL_PREFIX="$INTERNAL_PREFIX"
  export SHARED=""   # preserve existing meta.shared
  export OUT="${ARTIFACTS_ROOT}/${slug}/meta.json"
  write_hub_meta

  # clone engine + build full site from hub
  # (re-clone into same WORK: move src aside)
  local src_keep="$WORK/src-keep"
  mkdir -p "$src_keep"
  # WORK reused: clone_engine overwrites WORK assignment — fix by not resetting WORK
  local saved_work="$WORK"
  # clone into subdir without wiping WORK
  info "clone engine $FORGE_REPO (main)"
  GIT clone --depth 1 --branch main --quiet "$FORGE_REPO" "$saved_work/repo" \
    || die "clone impossible"
  WORK="$saved_work"
  [ -f "$WORK/repo/site/404.html" ] || die "site/404.html manquant"

  build_from_hub

  local dest path_url
  path_url="/${INTERNAL_PREFIX}/${slug}/"
  dest="$WORK/repo/site/${INTERNAL_PREFIX}/${slug}"
  [ -f "$dest/index.html" ] || die "build manquant index pour $slug"

  gen_og_images "$slug"
  inject_og_for_slug "$slug" "$title" "$desc" "$path_url"
  python3 "$(SCRIPTS)/inject-share-bar.py" "$dest/index.html" --slug "$slug" || true
  # persist bar into hub
  cp -f "$dest/index.html" "${ARTIFACTS_ROOT}/${slug}/index.html" || true
  # rebuild registry/index after og inject (og.jpg may be new)
  build_from_hub

  local share_url=""
  if $do_share; then
    share_url=$(create_share_kv "$slug")
    build_from_hub
    python3 "$(SCRIPTS)/inject-share-bar.py" \
      "$WORK/repo/site/${INTERNAL_PREFIX}/${slug}/index.html" --slug "$slug" || true
  fi

  if push_cf_deploy "feat(forge): publish $slug$($do_share && echo ' +share')"; then
    ok "publié (hub SSOT + ${DEPLOY_BRANCH})"
    echo "  Interne: https://${PUBLIC_HOST}${path_url}  (Access)"
    if [ -n "$share_url" ]; then
      echo "  Share:   $share_url  (public, unlisted)"
    fi
    hub_index_update "$slug"
  fi
}

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
