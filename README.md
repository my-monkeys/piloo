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

## État actuel

Phase : **cadrage terminé, pas encore de code**. La documentation est prête, le développement démarre.

## Licence

À définir.
