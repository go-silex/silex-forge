# Modèle share — forge.gosilex.com

## Pourquoi pas un path public ouvert (`/p/` — purgé)

| Approche | Problème |
|---|---|
| `/p/<slug>/` sans clé | Enumération + surface publique large |
| Toggle « public » sans secret | N’importe qui qui devine le slug lit le doc |
| `?k=` pur static HTML | La clé dans le JS/HTML = **pas** une vraie porte |

**Canon :** `/a/` (Access) + `/s/<slug>/<key>/` (Bypass + KV).

## Modèle retenu (intermédiaire)

```
Équipe (Access)                    Extérieur
─────────────────                  ─────────
/  catalogue  ─────────────────►  302 login Access
/a/<slug>/    ─────────────────►  302 login Access
                                    │
publish --share                     │
    ▼                               ▼
/s/<slug>/<key>/  ── Bypass ──►  200 si tu as le lien
                                    (pas sur le catalogue)
```

- **Clé** = segment de path haute entropie (`token_urlsafe(18)`)
- **Non listée** : `list_on_index` reste sur la carte *interne* ; le share n’ajoute pas de carte
- **Shortlink** : best-effort via `shlink` → `s.gosilex.com/f-<slug>`
- **Barre partage** (injectée sur `/a/<slug>/`) :
  - **Interne** — copie `https://forge.gosilex.com/a/<slug>/` (Access, pas de shlink)
  - **Externe** — `POST /api/share` → `/s/<slug>/<key>/` (+ shortlink shlink si secret Pages)
  - Badge **Partagé** + **Révoquer** quand un share externe est actif
  - Toast « copié » à chaque copie réussie
  - **`/p/` n’existe plus**

## Équivalence `?k=` (Roxabi 1page)

| 1page | Forge v2 |
|---|---|
| Worker compare `k` en constant-time | Access bypass `/s/*` + clé dans le path |
| Page absente du listing public | `list_on_index` / pas de carte share |
| Révocation = rotate key | `--unshare` supprime `/s/<slug>/` |

Cible long terme (**silex-share**) : même path, Worker + hash clé en D1/KV, ACL fine.

## Commandes

```bash
publish.sh mon-deck ./file.html --share
publish.sh --share mon-deck
publish.sh --unshare mon-deck
```

## Access CF (déjà créé)

| App | Domain | Policy |
|---|---|---|
| Silex Forge | `forge.gosilex.com` | Allow `@gosilex.com` + mickael@bouly.io |
| Silex Forge · share public | `forge.gosilex.com/s` | **Bypass** everyone |

## Mint au clic (v3 — 2026-07-17)

1. Barre **Externe** sur `/a/<slug>/` → `POST /api/share` `{ slug }` (interne = copie path Access sans API)
2. **Révoquer** → `DELETE /api/share` `{ slug }` (invalide la clé KV immédiatement)
3. API (Pages Function) écrit la clé en **KV** `SHARES`
4. URL renvoyée : `/s/<slug>/<key>/` — **Function** valide KV puis sert `/a/<slug>/` via ASSETS
5. Clipboard + toast
6. **⇧+Externe** = `rotate: true` (nouvelle clé, ancien lien mort)

Prérequis : être connecté via **Cloudflare Access** (JWT sur la requête).

## Landing = share live (KV)

Le catalogue embarque un snapshot registry (`shared` / badge share), puis au load (équipe Access) :

- `GET /api/share?slug=…` pour **chaque** artefact
- met à jour badge **share**, compteur « avec share », filtre **Partagé**
- re-sync au `focus` / `visibilitychange` (ex. après révoquer une slide puis revenir sur `/`)

Source de vérité share **runtime** = KV. Le registry reste utile pour le CLI / hub, pas pour l’UI live.

## `?k=` vs path key

| Forme | Exemple | Statut |
|---|---|---|
| Path (canonique) | `/s/passation-2026-07/<key>/` | **Oui** — KV + Function |
| Query (alias) | `/s/passation-2026-07/?k=<key>` | **Oui** — même clé KV |
| Query sur `/a/…` | `/a/slug/?k=` | Non (Access équipe) |

Ce n’est **pas** le modèle 1page (preview_key + Worker métier + Stripe).  
C’est le même *esprit* « secret dans l’URL » pour le share, avec garde serveur KV.
