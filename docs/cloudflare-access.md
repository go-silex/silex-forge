# Cloudflare Access — forge.gosilex.com

**But :** tout le host est **interne par défaut**.  
Certaines pages peuvent être **publiques** via le préfixe `/p/`.

## Modèle d’URL

| Préfixe | Visibilité | Access |
|---|---|---|
| `/` (catalogue) | Interne | **Protégé** |
| `/a/<slug>/` | Interne (défaut publish) | **Protégé** |
| `/s/<slug>/<key>/` | Share (opt-in `--share`) | **Bypass** — clé dans le path, **non listé** |
| `/images/…` | Assets | Protégé (équipe) |

Apps Zero Trust (créées 2026-07-17) :

| App | Domain | Policy |
|---|---|---|
| **Silex Forge** | `forge.gosilex.com` | Allow `@gosilex.com` + `mickael@bouly.io` |
| **Silex Forge · share public** | `forge.gosilex.com/s` | Bypass everyone |

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

### 2. Policy A — Bypass public paths (priorité haute)

| Champ | Valeur |
|---|---|
| Policy name | `public-p-prefix` |
| Action | **Bypass** |
| Include | **URI Path** → starts with → `/p/` |

Optionnel, si les assets publics référencent des images hors `/p/` :

- Include supplémentaire : URI Path starts with `/images/`  
  (sinon laisser images derrière Access — les HTML publics doivent être self-contained.)

**Ordre :** cette policy doit être **évaluée avant** la policy Allow team  
(Access applique la première policy qui matche selon la config UI — place Bypass en premier).

### 3. Policy B — Team only

| Champ | Valeur |
|---|---|
| Policy name | `team-gosilex` |
| Action | **Allow** |
| Include | **Emails ending in** → `@gosilex.com` |

Variantes utiles :

- **Google Workspace** identity provider + group `team@gosilex.com`
- Liste d’emails explicite (Pierre, Arman, Mickael…)
- OTP one-time pin pour invités ponctuels (policy séparée, courte durée)

### 4. Identity provider

Au minimum un IdP configuré dans Zero Trust :

- **One-time PIN** (email) — simple pour démarrer  
- ou **Google** / **GitHub** org `go-silex`

## Publier public vs interne

```bash
# Interne (défaut) → /a/my-deck/  + Access
./plugins/silex-forge/scripts/publish.sh my-deck ./deck.html \
  --title "Mon deck" --type deck

# Public → /p/my-deck/  + Bypass Access
./plugins/silex-forge/scripts/publish.sh my-deck ./deck.html \
  --public --title "Mon deck public" --type deck
```

Le registry (`registry/<slug>.json`) porte `"visibility": "internal"|"public"`.  
Le catalogue `/` liste les deux, mais **n’est visible qu’aux gens authentifiés**.

## Vérifications

```bash
# Sans cookie Access → doit rediriger vers login CF
curl -sI "https://forge.gosilex.com/" | head -5
curl -sI "https://forge.gosilex.com/a/github-claude-ops/" | head -5

# Public (après Bypass policy) → 200 direct
curl -sI "https://forge.gosilex.com/p/<slug>/" | head -5
```

## Ce que Access n’est pas

- Pas un ACL fin par artefact (c’est le job de **silex-share** plus tard).
- Bypass = **tout le préfixe `/p/`** est public — ne mets sous `/p/` que ce qui peut fuiter.
- Un shortlink `s.gosilex.com/x` vers `/a/…` restera bloqué par Access pour l’extérieur.

## Runbook incident

| Symptôme | Action |
|---|---|
| Équipe bloquée sur login | Vérifier policy Allow + IdP + emails |
| Page « publique » demande login | Policy Bypass `/p/` absente ou mal ordonnée |
| Ancien `/silex-talk-mcp/` 404 | Redirect 301 vers `/a/silex-talk-mcp/` (`site/_redirects`) |
| Catalogue liste un mort | `publish.sh --remove <slug>` |

## Références

- [Cloudflare Access self-hosted](https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/self-hosted-public-app/)
- [Bypass policies](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- Produit long terme : `silex-share` → `share.gosilex.com` (ACL + R2)
