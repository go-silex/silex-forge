# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| latest `main` / latest plugin release | yes |
| older tags | best effort |

## Reporting a vulnerability

**Do not** open a public GitHub issue for security problems.

1. Email **security@gosilex.com** with:
   - description and impact
   - steps to reproduce
   - affected paths (Functions, `publish.sh`, Access, share KV, etc.)
2. Allow reasonable time to fix before public disclosure.

If you do not have that contact, use [GitHub private vulnerability reporting](https://github.com/go-silex/silex-forge/security/advisories/new) on this repository.

## What to report

- Authentication or authorization bypass on `/a/*`, `/s/*`, or `/api/*`
- Share key leakage via HTML, registry, git, or catalogue
- Fail-open visibility (private content reachable without Access or share key)
- Secret exposure in repo, logs, or Pages responses

## Out of scope

- Missing rate limits on static HTML (expected on Pages)
- Social engineering against team members
- Issues on **forks** that do not use our production configuration
- Vulnerabilities in third-party services (Cloudflare, Shlink) — report to them directly

## Safe harbor

We appreciate responsible disclosure. We will not pursue legal action against researchers who follow this policy in good faith.

## Secrets reminder

Never paste in issues or PRs:

- `CLOUDFLARE_API_TOKEN`, `FORGE_SHARE_SECRET`, `SHLINK_API_KEY`
- Share URLs with live keys (`/s/<slug>/<key>/`)
- Contents of `~/.config/silex/forge.env`

Use `.env.example` placeholders only in the repository.
