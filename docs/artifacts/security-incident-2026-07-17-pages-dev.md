# Incident sécu — dual-origin + fake team auth (2026-07-17)

## Findings (confirmés live)

1. `silex-forge-6mm.pages.dev` servait catalogue + `/a/*` en 200 sans Access
2. `isTeamRequest` : header `X-Forge-Share-Secret` length>8 **ou** présence JWT non vérifié → droits équipe
3. GET `/api/share` renvoyait les clés en clair ; POST mint + shortlink Shlink
4. Clés aussi dans HTML `/a/` et `registry/*.json`

## Root causes

- Access hostname-bound (custom domain only) sur projet multi-origin Pages
- Auth applicative non crypto (escape hatch dev laissé en prod)
- Tooling OG dépendait de pages.dev « no Access »
- Secrets multi-SSOT (KV + git + HTML)

## Remediation appliquée

| Action | Statut |
|---|---|
| Access app `Silex Forge · pages.dev` | OK |
| Purge KV `share:*` | OK |
| Delete shortlinks `f-*` Shlink | OK |
| `functions/_middleware.ts` hard-block non-`/s` sur `*.pages.dev` | OK |
| JWT Access verify + `FORGE_SHARE_SECRET` constant-time | OK |
| GET sans `key` ; shareUrl canonique `forge.gosilex.com` | OK |
| Strip secrets HTML/registry ; inject slug only | OK |
| `FORGE_SHARE_SECRET` Pages + BW `silex-forge/FORGE_SHARE_SECRET` | OK |
| Docs Access/share-model | OK |

## Post-check

```bash
curl -sI https://silex-forge-6mm.pages.dev/          # 302 Access
curl -sI https://forge.gosilex.com/                   # 302 Access
# old keys → 404 on /s/
```

## Re-share

Équipe : se connecter Access → barre **Externe** sur `/a/<slug>/`  
CLI : `publish.sh --share <slug>` avec creds CF (KV seed, pas de key en git)
