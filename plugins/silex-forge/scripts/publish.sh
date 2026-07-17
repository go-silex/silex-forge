#!/usr/bin/env bash
# publish.sh — publie un artefact HTML sur forge.gosilex.com
#
#   publish.sh <slug> <fichier-ou-dossier> [--public] [--title "..."] [--type deck]
#   publish.sh --list
#   publish.sh --remove <slug>
#   publish.sh --rebuild-index   # regénère site/index.html + commit
#
# Modèle = silex-demos : l'accumulateur est le REPO git (pas un dossier local).
# CF Pages git-connected : `git push` = deploy. Zéro credential CF sur les postes.
#
# Visibilité :
#   défaut        → site/a/<slug>/  (derrière Cloudflare Access)
#   --public      → site/p/<slug>/  (bypass Access — policy CF /p/*)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# script lives in plugins/silex-forge/scripts → repo root = 3 levels up when installed in-repo
# When run from marketplace copy, FORGE_REPO must be set or we clone.
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
  publish.sh <slug> <path> [--public] [--title T] [--type TYPE] [--desc D]
  publish.sh --list
  publish.sh --remove <slug>
  publish.sh --rebuild-index

  slug     kebab-case [a-z0-9-]+
  path     fichier .html OU dossier contenant index.html
  --public publie sous /p/<slug>/ (public Access-bypass)
  défaut   /a/<slug>/ (interne, derrière Access)
EOF
}

validate_slug() {
  local s="${1-}"
  case "$s" in
    '' )            die "slug vide" ;;
    */*|*..*|.|.. ) die "slug invalide (path): '$s'" ;;
  esac
  [[ "$s" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "slug invalide (^[a-z0-9]+(-[a-z0-9]+)*$): '$s'"
  case "$s" in
    index|404|robots|registry|site|a|p|images|public|_headers) die "slug réservé: '$s'" ;;
  esac
}

whoami_id() { git config user.email 2>/dev/null || echo "${USER:-inconnu}@$(hostname)"; }

clone_repo() {
  WORK="$(mktemp -d)"
  info "clone $FORGE_REPO"
  GIT clone --depth 1 --branch main --quiet "$FORGE_REPO" "$WORK/repo" \
    || die "clone impossible — branche main ? accès GitHub go-silex/silex-forge ?"
  [ -d "$WORK/repo/site" ] || die "repo sans site/"
  [ -f "$WORK/repo/site/404.html" ] || die "site/404.html manquant (structurel Pages)"
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

write_registry() {
  local slug="$1" vis="$2" title="$3" typ="$4" desc="$5" path_url="$6"
  local day out
  day="$(date -u +%Y-%m-%d)"
  out="$WORK/repo/registry/${slug}.json"
  SLUG="$slug" VIS="$vis" TITLE="$title" TYP="$typ" DESC="$desc" PATHU="$path_url" DAY="$day" OUT="$out" \
  python3 - <<'PY'
import json, os
data = {
  "slug": os.environ["SLUG"],
  "title": os.environ["TITLE"],
  "description": os.environ["DESC"],
  "type": os.environ["TYP"],
  "visibility": os.environ["VIS"],
  "date": os.environ["DAY"],
  "path": os.environ["PATHU"],
}
path = os.environ["OUT"]
open(path, "w", encoding="utf-8").write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
print("registry", path)
PY
}

resolve_source() {
  # sets SRC_DIR with an index.html
  local input="$1"
  [ -e "$input" ] || die "source introuvable: $input"
  if [ -f "$input" ]; then
    case "$input" in
      *.html|*.htm) ;;
      *) die "fichier source doit être .html: $input" ;;
    esac
    STAGE="$WORK/src"
    mkdir -p "$STAGE"
    cp -f "$input" "$STAGE/index.html"
    SRC_DIR="$STAGE"
  elif [ -d "$input" ]; then
    [ -f "$input/index.html" ] || die "dossier sans index.html: $input"
    SRC_DIR="$input"
  else
    die "source invalide: $input"
  fi
}

cmd_list() {
  clone_repo
  info "artefacts enregistrés ($PUBLIC_HOST)"
  if ! ls "$WORK/repo/registry"/*.json &>/dev/null; then
    echo "  (vide)"
    return 0
  fi
  python3 - <<'PY'
import json, pathlib
reg = pathlib.Path.cwd()  # wrong
PY
  (
    cd "$WORK/repo"
    for f in registry/*.json; do
      python3 -c "
import json
d=json.load(open('$f'))
print(f\"  {d.get('visibility','?'):8}  {d.get('path','?'):28}  {d.get('title','')}\")
"
    done
  )
}

cmd_remove() {
  local slug="$1"
  validate_slug "$slug"
  clone_repo
  rm -rf "$WORK/repo/site/a/$slug" "$WORK/repo/site/p/$slug"
  rm -f "$WORK/repo/registry/${slug}.json"
  gen_index
  if commit_push "chore(forge): remove $slug"; then
    ok "retiré — https://${PUBLIC_HOST}/ (index)"
  fi
}

cmd_rebuild_index() {
  clone_repo
  gen_index
  if commit_push "chore(forge): rebuild index"; then
    ok "index regénéré — https://${PUBLIC_HOST}/"
  fi
}

cmd_publish() {
  local slug="$1" source="$2"
  shift 2
  local vis="internal" title="" typ="html" desc=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --public) vis="public"; shift ;;
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

  local prefix path_url dest
  if [ "$vis" = "public" ]; then
    prefix="p"
    path_url="/p/${slug}/"
  else
    prefix="a"
    path_url="/a/${slug}/"
  fi
  # drop from the other bucket if switching visibility
  rm -rf "$WORK/repo/site/a/$slug" "$WORK/repo/site/p/$slug"
  dest="$WORK/repo/site/${prefix}/${slug}"
  mkdir -p "$dest"
  # copy all files from source dir
  cp -a "$SRC_DIR"/. "$dest"/
  [ -f "$dest/index.html" ] || die "index.html manquant après copie"
  # build-id for smoke
  date -u +%Y%m%dT%H%M%SZ > "$dest/build-id.txt"

  write_registry "$slug" "$vis" "$title" "$typ" "$desc" "$path_url"
  gen_index

  if commit_push "feat(forge): publish $slug ($vis)"; then
    ok "publié"
    echo "  URL:  https://${PUBLIC_HOST}${path_url}"
    echo "  Vis:  $vis"
    if [ "$vis" = "public" ]; then
      echo "  ⚠ Access bypass requis pour /p/* (voir docs/cloudflare-access.md)"
    else
      echo "  🔒 derrière Cloudflare Access (défaut)"
    fi
    # optional shortlink for public only
    if [ "$vis" = "public" ] && command -v shlink &>/dev/null; then
      if shlink short -- "https://${PUBLIC_HOST}${path_url}" "$slug" 2>/dev/null; then
        ok "shortlink s.${SHLINK_DOMAIN#s.}/$slug (ou s.gosilex.com/$slug)"
      else
        warn "shlink a échoué — URL longue OK"
      fi
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
  --rebuild-index) cmd_rebuild_index ;;
  *)
    [ -n "${2-}" ] || { usage; exit 1; }
    cmd_publish "$@"
    ;;
esac
