# Cloudflare Pages — project `silex-forge`

## Target

| Field | Value |
|---|---|
| Pages project | `silex-forge` (or your `pages_project`) |
| Mode | **Direct Upload** (`wrangler pages deploy`) |
| Custom domain | `forge.gosilex.com` → CNAME to the project `pages.dev` (proxied) |
| Production | wrangler `--branch=main` (label only — no git-connected deploy) |

## Why not Git Integration

The repo is meant to be **public** (engine / plugin). Team HTML stays in **silex-hub**. A payload branch in the same repo = leak.

```
silex-hub / artifacts/<slug>/     SSOT — not git
        ↓ publish.sh (OG local + build)
temp clone engine (functions + skeleton)
        ↓ wrangler pages deploy
Pages project                     live
```

CF credentials = **laptop** (`~/.config/silex/forge.env`), not GitHub secrets.

Deploying with the wrong Cloudflare account breaks production — pin `CLOUDFLARE_ACCOUNT_ID` in `forge.env`.

## Machine config

| File | Role |
|---|---|
| `~/.config/silex/forge.config.json` | `hub_root`, `pages_project`, optional account/kv ids |
| `~/.config/silex/forge.env` | token + account + KV id · chmod 600 |
| [`.env.example`](../.env.example) | placeholders (safe to commit) |

```bash
cp .env.example ~/.config/silex/forge.env
chmod 600 ~/.config/silex/forge.env
# fill CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN, FORGE_SHARES_KV_ID
```

Token scopes: Pages Write + Read, Account Settings Read, **Workers KV Storage Edit** (CLI `--share`).

## Publish flow

```bash
plugins/silex-forge/scripts/forge-doctor.sh
plugins/silex-forge/scripts/publish.sh my-slug ./file.html --title "…"
plugins/silex-forge/scripts/publish.sh --rebuild-index
```

No HTML `git push`. No GitHub Action deploy.

`publish.sh` patches the cloned `wrangler.toml` before deploy:

- KV placeholder `YOUR_KV_NAMESPACE_ID` ← `FORGE_SHARES_KV_ID`
- plain `[vars]` ← `CF_ACCESS_TEAM_DOMAIN`, `CF_ACCESS_AUD`, `PUBLIC_HOST`, optional `SHLINK_API_URL` (fetched from Pages if missing locally)

Without that inject, `wrangler pages deploy` can wipe dashboard **plain** vars (secrets are kept).

## Pages env (Functions)

Set in the Cloudflare dashboard / API — **never commit values**.

| Var | Type | Role |
|---|---|---|
| `CF_ACCESS_TEAM_DOMAIN` | plain | Access team host |
| `CF_ACCESS_AUD` | plain | comma-separated application AUDs |
| `PUBLIC_HOST` | plain | canonical host for share URLs (e.g. `forge.gosilex.com`) |
| `SHLINK_API_KEY` | secret | Shlink API key — shortlinks on share |
| `SHLINK_API_URL` | plain | full create URL — **no default** |
| `FORGE_SHARE_SECRET` | secret | ops bypass for **POST/DELETE `/api/share` only** |
| KV `SHARES` | binding | share keys (`share:<slug>`) + visibility |

Local key material for ops (not git): e.g. `~/.config/silex/shlink-api-key`.

## Checklist

- [ ] Pages project + custom domain
- [ ] Access apps — [cloudflare-access.md](./cloudflare-access.md)
- [ ] Laptop `forge.env` on every publishing machine
- [ ] No `CLOUDFLARE_*` secrets in GitHub Actions
- [ ] Pages env vars above set; `wrangler.toml` has no real IDs
