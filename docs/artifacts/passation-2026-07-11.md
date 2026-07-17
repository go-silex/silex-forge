# Passation — slides GOSILEX (intention fondateurs)

> Deck = **5 sujets stratégiques**.  
> Schéma : **Aujourd’hui → Cas → Cible / pistes**.  
> Audits = ancrage terrain.

## Les 5 sujets

| # | Sujet | Intention |
|---|---|---|
| **01** | **CD automatisé** | Peu/pas de CD aujourd’hui. Cible : **pull** (Coolify / CD plateforme), pas push GitHub → serveur. |
| **02** | **Plateforme d’hébergement** | Stateless, data/fichiers managés, secrets hors VPS, **pas de VPS en prod**. **2 chemins** : **A** full Cloudflare (Pages, Workers, D1, R2, mail, WAF/rate limit) · **B** Next full-stack (Railway/Vercel/Netlify…) + Neon/Supabase, Resend, Upstash/Redis, etc. **Boilerplate ≠ selon le chemin.** |
| **03** | **Qualité apps SaaS** | Audits Spark + Metalyde : fuites sécu, coverage, god files, découpage, CI/linter. Standard : hooks, Biome, tests, e2e. **Coût CI** : repos privés → compute GH payant **ou** runners self-hosted sur VPS (moins cher, mais gourmand → dimensionner / limiter). VPS = atelier CI, pas prod multi-clients. Boilerplate lié à A ou B. |
| **04** | **Mémoire & compétences** | **1–2** : vault mélange / cas « hors dossier = sans outils ». **3** : chart L0→L1→L2 + montées (Dream) + compétences séparées (boucles ↔, revue humaine). |
| **05** | **MCP & plugin** | UX agent. MCP + skills + process, install 1 clic. Partenaires plateforme = horizon 2. |

## Structure deck (17 slides) — fil **1 → 2 → 3**

| # | Contenu | Étape |
|---|---|---|
| 01 | Cover | — |
| 02 | Mode d’emploi | méthode |
| 03–04 | CD (pipeline GitHub→humain→prod / pull) | **1** puis **2–3** |
| 05–06 | Plateforme (3 maisons → schémas A/B) | **1** puis **2–3** |
| 07 | Qualité Spark/Metalyde | **1–2** |
| 08–10 | Standard · **illustration** starter (piste, pas go) · coût CI | **3** |
| 11–12 | Mémoire (tiroir mixte → chart L0–L2 + skills) | **1–2** puis **3** |
| 13–14 | MCP | **1–2** puis **3** |
| 15 | **Synthèse enchaînement** (pas une 2ᵉ vue d’ensemble) | fil |
| 16 | **Ancrage preuves** (faits audit ≠ liste sujets) | preuves |
| 17–18 | **Annexe** : glossaire MCP/plugin/skill + install Code vs App (validé adversarial) | annexe |
| 19 | Closing : **roadmap + schéma directeur ensemble** | collab |

**Retiré** : doublon « vue d’ensemble 5 sujets » (ex-17) — fusionné dans 15.  
**Closing** : plus de « prochaines étapes » imposées — co-construction roadmap / schéma directeur technique.

### Slide 09 — ancrage stack (2026-07-12)

SSoT : `~/projects/gosilex/silex-share/AGENTS.md` (+ frame `artifacts/frames/001-share-platform-frame.md`).  
Statut deck : **stack figée · implémentation non démarrée**.

### Diagrammes (2026-07-12, v2 Silex-native)

Pas de fd-engine sombre dans le deck : **cartes CSS du design system deck** (Manrope, navy, tiles larges, titres 26–32px).

| Slide | Visuel |
|---|---|
| **06** | Chemin A = 4 grosses tuiles (SPA · Hono · D1+R2 · Better Auth) + colonne B list |
| **09** | Dual mission = 2 grandes cards (produit / kit) + pill repo + sidebar spine |

QA : `assets/diagrams/slide-06-verify.png` · `slide-09-verify.png`.

## Schéma A vs B (slide 06)

**A · Full Cloudflare** : Pages · Workers · D1 · R2 · mail CF · sécurité CF · secrets CF → boilerplate Workers.  
**B · Next + services** : Next sur Railway/Vercel/Netlify · Neon/Supabase · Storage · Resend · Upstash · secrets plateforme → boilerplate Next.

## Convention

- Pas de commit/push sans demande
- Deck = intention, pas décision d’implémentation détaillée
