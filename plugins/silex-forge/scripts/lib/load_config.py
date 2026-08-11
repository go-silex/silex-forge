#!/usr/bin/env python3
"""Load silex-forge config: local override → example fallback.

Resolution order for the config *file*:
  1) FORGE_CONFIG env (explicit path)
  2) ~/.config/silex/forge.config.json  (machine-local, per person)
  3) <plugin>/forge.config.example.json  (committed defaults)

Keys from example are always the base; local file deep-merges on top.
hub_root may still be empty after merge — doctor then fails until setup.

hub_root bootstrap (if empty string in config):
  a) HUB_ROOT env
  b) ~/.config/silex/hub-root (shared Silex machine config)
  c) leave empty (incomplete)

Usage as library:
  from load_config import load_config, artifacts_root, doctor

CLI:
  python3 load_config.py [--json|--doctor|--print-artifacts]
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any


PLUGIN_ROOT = Path(__file__).resolve().parents[2]
EXAMPLE_PATH = PLUGIN_ROOT / "forge.config.example.json"
LOCAL_PATH = Path.home() / ".config/silex/forge.config.json"
HUB_ROOT_FILE = Path.home() / ".config/silex/hub-root"

REQUIRED_KEYS = (
    "version",
    "hub_root",
    "artifacts_dir",
    "public_host",
    "forge_repo",
    "site_dir",
    "registry_dir",
    "internal_prefix",
)

VAULT_MARKERS = ("00_COCKPIT", "01_COMPANY")


def _read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        raise SystemExit(f"config unreadable: {path}: {e}") from e
    if not isinstance(data, dict):
        raise SystemExit(f"config must be a JSON object: {path}")
    return data


def _deep_merge(base: dict[str, Any], over: dict[str, Any]) -> dict[str, Any]:
    out = dict(base)
    for k, v in over.items():
        if k in out and isinstance(out[k], dict) and isinstance(v, dict):
            out[k] = _deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def config_paths() -> tuple[Path | None, Path]:
    """Return (active_local_or_env, example)."""
    env = os.environ.get("FORGE_CONFIG", "").strip()
    if env:
        return Path(env).expanduser(), EXAMPLE_PATH
    if LOCAL_PATH.is_file():
        return LOCAL_PATH, EXAMPLE_PATH
    return None, EXAMPLE_PATH


def _bootstrap_hub_root(current: str) -> str:
    cur = (current or "").strip()
    if cur:
        return str(Path(cur).expanduser())
    env = os.environ.get("HUB_ROOT", "").strip()
    if env:
        return str(Path(env).expanduser())
    if HUB_ROOT_FILE.is_file():
        line = HUB_ROOT_FILE.read_text(encoding="utf-8").strip()
        if line:
            return str(Path(line).expanduser())
    return ""


def load_config() -> dict[str, Any]:
    if not EXAMPLE_PATH.is_file():
        raise SystemExit(f"missing defaults: {EXAMPLE_PATH}")
    base = _read_json(EXAMPLE_PATH)
    active, _ = config_paths()
    if active is not None and active.is_file():
        cfg = _deep_merge(base, _read_json(active))
        cfg["_config_source"] = str(active.resolve())
        cfg["_config_fallback"] = False
    else:
        cfg = dict(base)
        cfg["_config_source"] = str(EXAMPLE_PATH.resolve())
        cfg["_config_fallback"] = True
    cfg["hub_root"] = _bootstrap_hub_root(str(cfg.get("hub_root") or ""))
    # normalize relative-looking home
    if cfg["hub_root"]:
        cfg["hub_root"] = str(Path(cfg["hub_root"]).expanduser().resolve())
    cfg.setdefault("shlink_domain", "s.gosilex.com")
    cfg.setdefault("types", ["deck", "talk", "guide", "diagram", "gallery", "html", "other"])
    return cfg


def artifacts_root(cfg: dict[str, Any] | None = None) -> Path | None:
    cfg = cfg or load_config()
    hub = (cfg.get("hub_root") or "").strip()
    rel = (cfg.get("artifacts_dir") or "").strip()
    if not hub or not rel:
        return None
    return (Path(hub) / rel).resolve()


def vault_ok(hub: Path) -> bool:
    return hub.is_dir() and all((hub / m).is_dir() for m in VAULT_MARKERS)


def doctor(cfg: dict[str, Any] | None = None) -> dict[str, Any]:
    """Return structured health check. ok=False ⇒ run forge-setup."""
    cfg = cfg or load_config()
    issues: list[str] = []
    warnings: list[str] = []

    for k in REQUIRED_KEYS:
        if k not in cfg:
            issues.append(f"clé manquante: {k}")

    if cfg.get("_config_fallback"):
        issues.append(
            f"pas de config locale — copier depuis example vers {LOCAL_PATH}"
        )

    hub_s = (cfg.get("hub_root") or "").strip()
    if not hub_s:
        issues.append("hub_root vide (path silex-hub différent par personne)")
        hub = None
    else:
        hub = Path(hub_s)
        if not hub.is_dir():
            issues.append(f"hub_root introuvable: {hub}")
        elif not vault_ok(hub):
            issues.append(
                f"hub_root n'est pas un vault silex-hub "
                f"(markers {', '.join(VAULT_MARKERS)}): {hub}"
            )

    art_rel = (cfg.get("artifacts_dir") or "").strip()
    if not art_rel:
        issues.append("artifacts_dir vide")
    art = artifacts_root(cfg)
    if art is not None and hub is not None and hub.is_dir():
        if not art.is_dir():
            warnings.append(f"artifacts_dir absent (sera créé au setup): {art}")

    for key in ("public_host", "forge_repo", "site_dir", "registry_dir", "internal_prefix"):
        if not str(cfg.get(key) or "").strip():
            issues.append(f"{key} vide")

    return {
        "ok": len(issues) == 0,
        "issues": issues,
        "warnings": warnings,
        "config_source": cfg.get("_config_source"),
        "fallback": bool(cfg.get("_config_fallback")),
        "hub_root": hub_s or None,
        "artifacts_root": str(art) if art else None,
        "local_path": str(LOCAL_PATH),
        "example_path": str(EXAMPLE_PATH),
        "skill": "forge-setup",
    }


def export_env(cfg: dict[str, Any] | None = None) -> str:
    """Shell-friendly KEY=value lines for publish.sh sourcing."""
    cfg = cfg or load_config()
    art = artifacts_root(cfg)
    pairs = {
        "FORGE_PUBLIC_HOST": cfg.get("public_host", "forge.gosilex.com"),
        "FORGE_REPO": cfg.get("forge_repo", ""),
        "FORGE_SHLINK_DOMAIN": cfg.get("shlink_domain", "s.gosilex.com"),
        "FORGE_HUB_ROOT": cfg.get("hub_root") or "",
        "FORGE_ARTIFACTS_DIR": cfg.get("artifacts_dir") or "",
        "FORGE_ARTIFACTS_ROOT": str(art) if art else "",
        "FORGE_SITE_DIR": cfg.get("site_dir", "site"),
        "FORGE_REGISTRY_DIR": cfg.get("registry_dir", "registry"),
        "FORGE_INTERNAL_PREFIX": cfg.get("internal_prefix", "a"),
        "FORGE_CONFIG_SOURCE": cfg.get("_config_source", ""),
        "FORGE_CONFIG_FALLBACK": "1" if cfg.get("_config_fallback") else "0",
    }
    lines = []
    for k, v in pairs.items():
        # safe single-quote shell escape
        esc = str(v).replace("'", "'\"'\"'")
        lines.append(f"{k}='{esc}'")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    args = argv[1:]
    if "--doctor" in args or "-c" in args or "--check" in args:
        d = doctor()
        print(json.dumps(d, ensure_ascii=False, indent=2))
        return 0 if d["ok"] else 1
    if "--print-artifacts" in args:
        art = artifacts_root()
        if not art:
            print("", end="")
            return 1
        print(art)
        return 0
    if "--export-env" in args:
        sys.stdout.write(export_env())
        return 0
    # default: full merged config as JSON
    cfg = load_config()
    # strip internal keys for clean dump unless --all
    if "--all" not in args:
        cfg = {k: v for k, v in cfg.items() if not k.startswith("_")}
    print(json.dumps(cfg, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
