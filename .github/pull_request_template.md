## Summary

<!-- What does this PR change and why? -->

## Type

- [ ] fix
- [ ] feat
- [ ] docs
- [ ] chore (release, CI, tooling)

## Checklist

- [ ] **No secrets** — no tokens, share keys, account/KV/AUD IDs, or real `forge.env` / `forge.config.json`
- [ ] **No HTML payloads** — no `site/a/**`, `site/index.html`, `registry/*.json`
- [ ] Docs/skills updated if user-facing behavior changed
- [ ] [CHANGELOG.md](CHANGELOG.md) updated (Unreleased or version section)
- [ ] Plugin version bumped in `.claude-plugin/marketplace.json` and `plugins/silex-forge/.claude-plugin/plugin.json` if plugin surface changed
- [ ] `bash -n plugins/silex-forge/scripts/publish.sh` passes locally

## Test plan

<!-- How did you verify? e.g. forge-doctor, publish dry-run, manual Access check -->
