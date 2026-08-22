# Going public — checklist

## HEAD (this commit)

- No HTML payloads in tree (`site/a`, `registry`, `manifest.json`)
- No Cloudflare account / KV / Access AUD in committed files
- Secrets only in `~/.config/silex/forge.env` and Pages dashboard

## Git history (required before open-source)

Older commits may still contain:

- `site/a/**`, `site/manifest.json`, `registry/**` (internal catalogue)
- `wrangler.toml` with real KV namespace ID and Access AUDs

**HEAD being clean is not enough.** Run:

```bash
scripts/purge-git-history.sh
# then coordinate force-push with the team:
# git push --force-with-lease origin main
```

Requires [git-filter-repo](https://github.com/newren/git-filter-repo).

## After purge

1. Fresh clone on a clean machine — grep history for `758e41ae`, `f6b214db`, client slug names
2. Set repo visibility to public
3. Confirm Pages env vars still set (deploy injects from `forge.env`)

## Ops credentials (never in git)

| File | Contents |
|---|---|
| `~/.config/silex/forge.env` | token, account, KV, Access, `PUBLIC_HOST`, optional `SHLINK_API_URL` |
| Pages secrets | `SHLINK_API_KEY`, `FORGE_SHARE_SECRET` |

Copy from [`.env.example`](../.env.example).
