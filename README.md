# Piloo

> Carnet numérique de médicaments pour la maison — un pont léger entre les particuliers, les aidants, et les professionnels de santé à domicile.

## Vision

Permettre à chacun de gérer son armoire à pharmacie comme une vraie officine : scanner ses boîtes, connaître ses stocks, suivre ses prises. Pour les professionnels de santé à domicile (aides-soignants, IDEL), maintenir à jour l'inventaire de leurs patients avec un partage bidirectionnel et des alertes.

**Positionnement** : carnet de suivi personnel numérique. Pas un dispositif médical, pas un outil de validation clinique. Juste un meilleur cahier.

## Pour démarrer

1. Lire `docs/dossier-cadrage.md` pour la vision complète
2. Lire `docs/spec.md` pour les spécifications fonctionnelles
3. Lire `docs/architecture.md` pour les décisions techniques
4. Consulter `CLAUDE.md` (ou les `CLAUDE.md` de chaque app/package) pour travailler avec Claude Code

## Structure

```
mon-officine/
├── README.md                  → Ce fichier
├── CLAUDE.md                  → Instructions Claude Code (contexte global)
├── docs/                      → Documentation projet
│   ├── dossier-cadrage.md     → Vision produit complète
│   ├── spec.md                → Spécifications fonctionnelles
│   ├── architecture.md        → Architecture technique
│   ├── data-model.md          → Modèle de données
│   ├── api-contract.md        → Conventions API REST + OpenAPI
│   ├── ui-ux-guidelines.md    → Guidelines UI/UX
│   └── roadmap.md             → Planning M1-M3
├── apps/
│   ├── web/                   → Application web Next.js 15
│   └── mobile/                → Application mobile Flutter
├── packages/
│   ├── db-schema/             → Schéma Drizzle + migrations Postgres
│   └── api-contract/          → Schémas Zod + OpenAPI généré
├── .gitignore
└── .env.example
```

## Stack

- **Mobile** : Flutter 3.x + Dart
- **Web** : Next.js 15 (App Router) + TypeScript
- **Backend** : API Routes Next.js + Zod + OpenAPI
- **DB** : PostgreSQL + Drizzle ORM
- **DB mobile locale** : SQLite + Drift
- **Monorepo** : Turborepo (pour le JS/TS, Flutter cohabite à côté)

## Commandes (onboarding dev)

Toutes les commandes JS/TS se lancent à la racine via **pnpm + Turborepo**. Flutter (`apps/mobile`) a son propre tooling (`flutter pub get`, `flutter run`, etc.).

| Commande | Description |
|---|---|
| `pnpm dev` | Lance l'app web Next.js (`apps/web`) en mode développement (hot reload, http://localhost:3000). |
| `pnpm test` | Exécute les tests unitaires de tous les packages JS/TS (Vitest). |
| `pnpm lint` | Lint ESLint + Prettier sur tout le monorepo. À passer avant chaque commit. |
| `pnpm openapi:generate` | Régénère `packages/api-contract/openapi.yaml` depuis les schémas Zod, puis les clients TS et Dart. À relancer après toute modification des schémas Zod côté backend. |

> Pré-requis : Node ≥ 20, pnpm ≥ 9. Pour mobile : Flutter 3.x. Voir `.env.example` pour les variables d'environnement requises.

## État actuel

Phase : **cadrage terminé, pas encore de code**. La documentation est prête, le développement démarre.

## Licence

À définir.
