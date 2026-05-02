# Instructions Claude Code — packages/db-schema

Schéma Drizzle ORM pour PostgreSQL. Source de vérité du modèle de données côté serveur.

## Stack

- **Drizzle ORM** + **Drizzle Kit** (migrations)
- **PostgreSQL** (Neon ou Railway en hébergement managé)

## Structure attendue

```
packages/db-schema/
├── src/
│   ├── schema/
│   │   ├── users.ts
│   │   ├── officines.ts
│   │   ├── partages.ts
│   │   ├── boites.ts
│   │   ├── ordonnances.ts
│   │   ├── prescriptions.ts
│   │   ├── prises.ts
│   │   ├── alertes.ts
│   │   ├── bdpm.ts                 → medicaments_bdpm, substances, resumes_ia
│   │   └── index.ts                → exports centralisés
│   ├── migrations/                 → SQL généré par Drizzle Kit
│   ├── seed.ts                     → seed de dev (optionnel)
│   └── index.ts
├── drizzle.config.ts
├── package.json
└── CLAUDE.md                       → ce fichier
```

## Conventions

- **Colonnes en snake_case** dans la DB.
- **Types TS exportés** pour chaque table (`export type User = typeof users.$inferSelect`).
- **IDs** : UUID v4 (pas de serial, pour permettre la création offline côté mobile).
- **Timestamps** : `timestamp().defaultNow().notNull()` ou `timestamp()` pour nullable.
- **Soft delete** : toutes les tables métier ont `deleted_at: timestamp()` nullable.
- **Indexes** : documentés dans le schéma avec `index()`.

## Migrations

- Générées avec `pnpm db:generate` (drizzle-kit).
- Appliquées avec `pnpm db:migrate`.
- Commitées dans `migrations/` (jamais supprimées).
- Nommage : `drizzle-kit` choisit auto, renommer si plus explicite.

## Référence

Schéma détaillé : `/docs/data-model.md`. Toute modification de schéma doit d'abord être reflétée/discutée dans ce document.

## Ce que Claude Code doit faire

1. Lire `/docs/data-model.md` avant de créer ou modifier une table.
2. Toujours générer la migration (`pnpm db:generate`) après modif du schéma.
3. Ne JAMAIS supprimer une migration existante (la corriger par une nouvelle).
4. Respecter le soft delete sur toutes les tables métier.
