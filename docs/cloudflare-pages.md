# Cloudflare Pages — projet `silex-forge`

## Cible

| Champ | Valeur |
|---|---|
| Projet Pages | `silex-forge` |
| Compte | Tool@gosilex.com (Gosilex) |
| Source | **Git integration** `go-silex/silex-forge` branche `main` |
| Build command | *(vide)* |
| Build output directory | **`site`** |
| Domaine custom | `forge.gosilex.com` |
| Production branch | `main` |

⚠️ **Git integration, pas Direct Upload.**  
`wrangler pages project create` crée du Direct Upload (irréversible) — **ne pas l’utiliser** pour ce projet. Brancher le repo depuis le dashboard Pages « Connect to Git ».

## Pourquoi git (comme silex-demos)

- Un seul arbre servi → toutes les pubs coexistent
- `git push` = deploy (pas de token CF sur les postes)
- Concurrence = non-fast-forward (pas d’écrasement silencieux)

## Création (checklist)

1. Créer le repo GitHub `go-silex/silex-forge` (privé) — fait via `gh`
2. Dashboard CF → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**
3. Autoriser org `go-silex`, sélectionner `silex-forge`
4. Build settings :
   - Framework preset : None
   - Build command : *(empty)*
   - Build output directory : `site`
5. Save and Deploy
6. Custom domains → `forge.gosilex.com` (CNAME vers `silex-forge.pages.dev`)
7. Configurer Access : [`cloudflare-access.md`](./cloudflare-access.md)

## Migration depuis `~/.roxabi/silex-forge`

Ancien chemin = **Direct Upload** + dossier local (projet CF parfois disparu / hors inventaire).  
Nouveau = ce repo. Les artefacts seedés :

- `/a/silex-talk-mcp/` (ex `/silex-talk-mcp/`, redirect 301)
- `/a/github-claude-ops/`

## path_includes (optionnel)

Dans les settings build, si dispo : ne builder que si `site/**` change — les commits purement `plugins/` ne redéploient pas.
