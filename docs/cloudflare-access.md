# Cloudflare Access — forge.gosilex.com

**But :** tout le host est **interne par défaut**.  
Seul le préfixe **`/s/*`** (liens share à clé) est en Bypass Access.

## Modèle d’URL

| Préfixe | Visibilité | Access |
|---|---|---|
| `/` (catalogue) | Interne | **Protégé** |
| `/a/<slug>/` | Interne (défaut publish) | **Protégé** |
| `/s/<slug>/<key>/` | Share (opt-in) | **Bypass** — clé dans le path, **non listé** |
| `/images/…` | Assets équipe | Protégé |

> **`/p/` purgé** — plus de path « public sans clé ». Utiliser **Externe** / `--share` → `/s/…`.

Apps Zero Trust (créées 2026-07-17, pages.dev 2026-07-17) :

| App | Domain | Policy |
|---|---|---|
| **Silex Forge** | `forge.gosilex.com` | Allow `@gosilex.com` + `mickael@bouly.io` |
| **Silex Forge · share public** | `forge.gosilex.com/s` | Bypass everyone |
| **Silex Forge · pages.dev** | `silex-forge-6mm.pages.dev` | Allow team (même policy) |

### Invariant hostnames

Access sur le **custom domain seul ne suffit pas**. Le projet Pages expose aussi `*.pages.dev` avec les **mêmes ASSETS**.

| Host | Contenu équipe (`/`, `/a/*`) | Share `/s/*` |
|---|---|---|
| `forge.gosilex.com` | Access Allow | Bypass + clé KV |
| `silex-forge-6mm.pages.dev` | Access **+** middleware 403 (defense-in-depth) | Function KV only |

**Ne jamais** utiliser pages.dev comme sonde OG « sans Access ». Vérifier en local (`verify-og.py --file`).

## Setup Zero Trust (une fois)

Compte CF **Tool@gosilex.com** · zone `gosilex.com`.

### 1. Application self-hosted

1. [Zero Trust](https://one.dash.cloudflare.com/) → **Access** → **Applications** → **Add**
2. Type : **Self-hosted**
3. Application name : `Silex Forge`
4. Session duration : 24h (ou 30j)
5. Application domain :
   - Subdomain : `forge`
   - Domain : `gosilex.com`
   - Path : *(vide = tout le host)*  
   → `forge.gosilex.com`

### 2. Policy A — Team only

| Champ | Valeur |
|---|---|
| Policy name | `team-gosilex` |
| Action | **Allow** |
| Include | **Emails ending in** → `@gosilex.com` |

Variantes utiles :

- **Google Workspace** identity provider + group `team@gosilex.com`
- Liste d’emails explicite (Pierre, Arman, Mickael…)
- OTP one-time pin pour invités ponctuels (policy séparée, courte durée)

### 3. Application Bypass pour `/s`

App séparée (ou path policy) :

| Champ | Valeur |
|---|---|
| Application name | `Silex Forge · share public` |
| Domain | `forge.gosilex.com` path `/s` |
| Policy | **Bypass** everyone |

**Ops (2026-07-17) :** pas de policy Bypass `/p/` sur le compte — apps actives =  
`Silex Forge` (Allow team) + `Silex Forge · share public` (`/s` Bypass). Rien à purger côté Access.

### 4. Identity provider

Au minimum un IdP configuré dans Zero Trust :

- **One-time PIN** (email) — simple pour démarrer  
- ou **Google** / **GitHub** org `go-silex`

## Publier interne + share

```bash
# Interne (défaut) → /a/my-deck/  + Access
./plugins/silex-forge/scripts/publish.sh my-deck ./deck.html \
  --title "Mon deck" --type deck

# + lien share → /s/my-deck/<key>/  (Bypass, unlisted)
./plugins/silex-forge/scripts/publish.sh my-deck ./deck.html \
  --share --title "Mon deck" --type deck
```

## Vérifications

```bash
# Sans cookie Access → doit rediriger vers login CF
curl -sI "https://forge.gosilex.com/" | head -5
curl -sI "https://forge.gosilex.com/a/github-claude-ops/" | head -5

# pages.dev ne doit PAS servir le catalogue /a en clair (403 middleware et/ou Access)
curl -sI "https://silex-forge-6mm.pages.dev/" | head -5
curl -sI "https://silex-forge-6mm.pages.dev/a/github-claude-ops/" | head -5

# Fake team headers morts
curl -s "https://silex-forge-6mm.pages.dev/api/share?slug=x" \
  -H "X-Forge-Share-Secret: 123456789"

# Share (clé connue) → 200 sans cookie
curl -sI "https://forge.gosilex.com/s/<slug>/<key>/" | head -5

# Ancien /p/ ne doit plus servir de contenu
curl -sI "https://forge.gosilex.com/p/" | head -5
```

## Ce que Access n’est pas

- Pas un ACL fin par artefact (c’est le job de **silex-share** plus tard).
- Bypass = **préfixe `/s/`** seulement — la vraie garde est la **clé** validée en KV par la Function.
- Un shortlink `s.gosilex.com/x` vers `/a/…` restera bloqué par Access pour l’extérieur.

## Runbook incident

| Symptôme | Action |
|---|---|
| Équipe bloquée sur login | Vérifier policy Allow + IdP + emails |
| Share demande login | App Bypass `/s` absente ou mal ordonnée |
| Share 404 après Révoquer | Attendu — clé KV supprimée |
| Ancien `/silex-talk-mcp/` 404 | Redirect 301 vers `/a/silex-talk-mcp/` (`site/_redirects`) |
| Catalogue liste un mort | `publish.sh --remove <slug>` |

## Références

- [Cloudflare Access self-hosted](https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/self-hosted-public-app/)
- [Bypass policies](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- Produit long terme : `silex-share` → `share.gosilex.com` (ACL + R2)
