# Instructions Claude Code — packages/api-contract

Schémas Zod définissant le contrat API REST. Source de vérité des formats d'entrée/sortie, propagée vers web (TS) et mobile (Dart) via OpenAPI.

## Stack

- **Zod** pour les schémas
- **zod-to-openapi** pour la génération OpenAPI
- **openapi-typescript** pour les types TS (web)
- **openapi-generator-cli** ou équivalent Dart pour le client mobile

## Structure attendue

```
packages/api-contract/
├── src/
│   ├── schemas/
│   │   ├── auth.ts                 → Register, Login, User
│   │   ├── officines.ts
│   │   ├── partages.ts
│   │   ├── boites.ts
│   │   ├── ordonnances.ts
│   │   ├── prescriptions.ts
│   │   ├── prises.ts
│   │   ├── alertes.ts
│   │   ├── sync.ts                 → SyncPushRequest, SyncPullResponse
│   │   ├── bdpm.ts
│   │   ├── errors.ts               → Format d'erreur standard
│   │   └── index.ts
│   ├── openapi.ts                  → génération du doc OpenAPI
│   └── index.ts
├── openapi.yaml                    → artefact généré (commité)
├── package.json
└── CLAUDE.md                       → ce fichier
```

## Conventions

- **Schémas par entité** : pour chaque entité métier, définir :
  - `XxxSchema` : schéma complet (représentation DB)
  - `CreateXxxInputSchema` : body d'une création
  - `UpdateXxxInputSchema` : body d'une update (souvent `.partial()`)
  - `XxxResponseSchema` : ce que l'API retourne
- **Casing** : snake_case dans les schémas (conforme à la convention API).
- **Réutilisation** : utiliser `.pick()`, `.omit()`, `.extend()` pour éviter la duplication.
- **Dates** : toujours ISO 8601 via `z.string().datetime()` ou `.date()`.

## Exemple

```ts
import { z } from 'zod';
import { extendZodWithOpenApi } from 'zod-to-openapi';

extendZodWithOpenApi(z);

export const BoiteSchema = z.object({
  id: z.string().uuid(),
  officine_id: z.string().uuid(),
  cip13: z.string().length(13),
  lot: z.string().nullable(),
  numero_serie: z.string().nullable(),
  peremption: z.string().date(),
  unites_restantes: z.number().int().min(0).nullable(),
  statut: z.enum(['active', 'vide', 'perimee']),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
}).openapi('Boite');

export const CreateBoiteInputSchema = BoiteSchema.pick({
  cip13: true,
  lot: true,
  numero_serie: true,
  peremption: true,
  unites_restantes: true,
});

export type Boite = z.infer<typeof BoiteSchema>;
export type CreateBoiteInput = z.infer<typeof CreateBoiteInputSchema>;
```

## Génération OpenAPI

- Script `pnpm generate` qui :
  1. Construit le document OpenAPI depuis les schémas Zod.
  2. Écrit `openapi.yaml` dans le package.
  3. Déclenche (via Turborepo) la génération du client TS et Dart.
- `openapi.yaml` est commité.
- La CI échoue si `openapi.yaml` n'est pas à jour par rapport aux schémas Zod.

## Référence

- `/docs/api-contract.md` — conventions REST et liste des endpoints.
- `/docs/data-model.md` — modèle DB (base des schémas).

## Ce que Claude Code doit faire

1. Lire `/docs/api-contract.md` avant d'ajouter un endpoint.
2. Définir les schémas Zod AVANT de coder l'implémentation côté Next.js.
3. Exécuter la génération OpenAPI après toute modification.
4. Vérifier la cohérence avec le schéma Drizzle de `packages/db-schema`.
