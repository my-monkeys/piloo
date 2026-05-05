# #32 — Tables `users` + `officines` + `partages`

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Poser le premier schéma Drizzle réel (users + officines + partages) avec migration générée, contraintes/soft-delete enforced en DB, et tests d'invariants vérifiant les règles métier.

**Architecture:**

- 3 fichiers de schéma Drizzle dans `packages/db-schema/src/schema/`, ré-exportés via le barrel.
- Helper `createDb(url)` pour instancier un client Drizzle (utilisé par les tests, plus tard par les API routes).
- Tests d'invariants Vitest contre un Postgres jetable lancé par **testcontainers** (zéro config locale ni CI). Drizzle-kit migre la DB au démarrage de chaque suite.
- Première migration générée par `drizzle-kit generate` et committée.

**Tech Stack:** Drizzle ORM 0.36 (pinné), drizzle-kit 0.30, postgres-js 3.x (déjà en deps), Vitest, `@testcontainers/postgresql`. Pas de Zod ici (réservé à #69/#70 côté `@piloo/api-contract`).

---

## File Structure

```
packages/db-schema/
├── src/
│   ├── schema/
│   │   ├── users.ts          [NEW]  table users + enum type_compte + types inférés
│   │   ├── officines.ts      [NEW]  table officines + enum type_officine + FK users + types
│   │   ├── partages.ts       [NEW]  table partages + enum role + FKs + partial unique + types
│   │   └── index.ts          [NEW]  re-exporte les 3 schémas + types
│   ├── db.ts                 [NEW]  factory createDb(url) -> Drizzle client
│   └── index.ts              [MODIFY] export schema + db
├── test/
│   ├── setup.ts              [NEW]  setupTestDb() : testcontainers + migrate
│   ├── users.test.ts         [NEW]  invariants users
│   ├── officines.test.ts     [NEW]  invariants officines (FK + soft delete)
│   └── partages.test.ts      [NEW]  invariants partages (partial unique + reinsert)
├── migrations/
│   ├── 0000_*.sql            [NEW, généré]
│   └── meta/                 [NEW, généré]
├── drizzle.config.ts         [pas de changement]
├── package.json              [MODIFY] deps testcontainers/drizzle-orm/postgres + script test
└── tsconfig.json             [pas de changement]
```

Aucun fichier > 200 lignes attendu. Chaque schéma fait ~40 lignes, chaque suite de tests ~80.

**Pas modifié dans ce plan** : `apps/web` (pas encore initialisé), `packages/api-contract` (pas de Zod schemas équivalents — c'est #69/#70), CI workflows (testcontainers tourne dans le job ubuntu-latest, pas besoin de service postgres).

---

## Conventions à respecter

Tirées de `packages/db-schema/CLAUDE.md` et `docs/data-model.md` :

- **`pgTable`** : nom de table en `snake_case` explicite ; le `casing: 'snake_case'` de `drizzle.config.ts` dérive auto les noms de colonnes depuis camelCase TS, donc on omet le 1er argument des helpers de colonne (`uuid()`, pas `uuid('id')`) sauf cas justifié.
- **IDs** : `uuid().primaryKey().$defaultFn(() => crypto.randomUUID())` — UUID v4 généré côté client pour permettre l'offline-first.
- **Timestamps** : `timestamp({ withTimezone: true })`, jamais `withTimezone: false`. Postgres = UTC strict.
- **Soft delete** : toutes les tables métier ont `deletedAt: timestamp({ withTimezone: true })` nullable.
- **Audit** : `createdAt` + `updatedAt` `.notNull().defaultNow()`.
- **Types inférés** : pour chaque table, exporter `export type Xxx = typeof xxx.$inferSelect; export type NewXxx = typeof xxx.$inferInsert;`.
- **Enums** : `pgEnum('nom_enum', ['v1', 'v2'])` exportés depuis le module qui les utilise.

---

## Task 1 : Deps + factory `createDb`

**Files:**

- Modify: `packages/db-schema/package.json`
- Create: `packages/db-schema/src/db.ts`
- Modify: `packages/db-schema/src/index.ts`

- [ ] **Step 1.1 — Ajouter les deps**

Ajouter `@testcontainers/postgresql` (devDep), bumper `typescript` à 5.9, ajouter le script `test`.

```bash
pnpm --filter @piloo/db-schema add -D @testcontainers/postgresql vitest@^4.1.5 @types/node
```

Puis éditer `packages/db-schema/package.json` :

```json
{
  "name": "@piloo/db-schema",
  "private": true,
  "version": "0.0.0",
  "description": "Schéma Drizzle ORM (PostgreSQL) — source de vérité du modèle de données serveur",
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "generate": "drizzle-kit generate",
    "migrate": "drizzle-kit migrate",
    "studio": "drizzle-kit studio",
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "drizzle-orm": "^0.36.4",
    "postgres": "^3.4.5"
  },
  "devDependencies": {
    "@testcontainers/postgresql": "^11.4.0",
    "@types/node": "^25.6.0",
    "drizzle-kit": "^0.30.1",
    "typescript": "^5.9.3",
    "vitest": "^4.1.5"
  }
}
```

- [ ] **Step 1.2 — Créer `src/db.ts`**

```ts
// packages/db-schema/src/db.ts
// Factory partagée : tests + (plus tard) API routes Next.js construisent leur
// client Drizzle via createDb(url). On ne réexporte pas un singleton — chaque
// caller gère son propre cycle de vie (close() après usage).
import { drizzle, type PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres, { type Sql } from 'postgres';

import * as schema from './schema/index.ts';

export type Db = PostgresJsDatabase<typeof schema>;

export interface DbHandle {
  readonly db: Db;
  readonly client: Sql;
  close: () => Promise<void>;
}

export function createDb(url: string): DbHandle {
  const client = postgres(url, { max: 5, prepare: false });
  const db = drizzle(client, { schema });
  return {
    db,
    client,
    close: async () => {
      await client.end({ timeout: 5 });
    },
  };
}
```

- [ ] **Step 1.3 — Mettre à jour `src/index.ts`**

```ts
// packages/db-schema/src/index.ts
export * from './schema/index.ts';
export { createDb, type Db, type DbHandle } from './db.ts';
```

- [ ] **Step 1.4 — Vérifier que `pnpm typecheck` passe**

Run: `pnpm --filter @piloo/db-schema typecheck`
Expected: pas d'erreur (le module schema/index.ts n'existe pas encore → erreur attendue, on la corrige à la Task 2 step 2.4 quand on crée le barrel).

> Si tu veux unblocker tout de suite : crée un barrel temporaire vide :
> `echo "export {};" > packages/db-schema/src/schema/index.ts`

- [ ] **Step 1.5 — Commit**

```bash
git add packages/db-schema/package.json packages/db-schema/src/db.ts packages/db-schema/src/index.ts pnpm-lock.yaml
git commit -m "feat(db): add createDb factory + dev deps testcontainers/vitest (#32)"
```

---

## Task 2 : Test infra avec testcontainers

**Files:**

- Create: `packages/db-schema/test/setup.ts`
- Create: `packages/db-schema/src/schema/index.ts` (barrel vide pour débloquer le typecheck)

- [ ] **Step 2.1 — Test "il y a un container Postgres" (fail attendu)**

Créer `packages/db-schema/test/setup.test.ts` (sera supprimé à la fin de la Task 2) :

```ts
import { afterAll, beforeAll, expect, it } from 'vitest';

import { setupTestDb, type TestDb } from './setup.ts';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 60_000);

afterAll(async () => {
  await env.teardown();
});

it('peut interroger un container Postgres jetable', async () => {
  const result = await env.handle.client`SELECT 1 AS one`;
  expect(result[0]?.one).toBe(1);
});
```

- [ ] **Step 2.2 — Run test, vérifier l'échec**

Run: `pnpm --filter @piloo/db-schema test`
Expected: FAIL — `setup.ts` n'existe pas / module not found.

- [ ] **Step 2.3 — Créer `test/setup.ts`**

```ts
// packages/db-schema/test/setup.ts
// Lance un Postgres jetable via testcontainers, applique les migrations Drizzle,
// expose un DbHandle. Appelé en beforeAll dans chaque suite. Idempotent — un
// container par suite, teardown obligatoire en afterAll.
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

import { createDb, type DbHandle } from '../src/db.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_FOLDER = resolve(HERE, '..', 'migrations');

export interface TestDb {
  readonly handle: DbHandle;
  readonly url: string;
  teardown: () => Promise<void>;
}

export async function setupTestDb(): Promise<TestDb> {
  const container: StartedPostgreSqlContainer = await new PostgreSqlContainer('postgres:16-alpine')
    .withDatabase('piloo_test')
    .withUsername('piloo')
    .withPassword('piloo')
    .start();

  const url = container.getConnectionUri();
  const handle = createDb(url);

  await migrate(handle.db, { migrationsFolder: MIGRATIONS_FOLDER });

  return {
    handle,
    url,
    teardown: async () => {
      await handle.close();
      await container.stop();
    },
  };
}

export async function truncateAll(handle: DbHandle): Promise<void> {
  // Ordre de TRUNCATE inverse des FKs. Cascade pour gérer les liens.
  await handle.client`TRUNCATE TABLE partages, officines, users RESTART IDENTITY CASCADE`;
}
```

- [ ] **Step 2.4 — Créer le barrel des schémas (vide pour l'instant)**

```ts
// packages/db-schema/src/schema/index.ts
// Barrel des schémas Drizzle. Les tables seront ajoutées dans les Tasks 3-5.
export {};
```

Supprimer le `.gitkeep` :

```bash
rm packages/db-schema/src/schema/.gitkeep
```

- [ ] **Step 2.5 — Run test : il échoue toujours (pas de migrations)**

Run: `pnpm --filter @piloo/db-schema test`
Expected: échec sur `migrate` car `migrations/` n'existe pas.

> C'est attendu — la Task 6 régénérera les migrations. Pour faire passer cette task isolément, on neutralise temporairement la migration : commenter l'appel à `migrate(...)` dans `setup.ts` puis relancer.

- [ ] **Step 2.6 — Test passe (sans migration)**

Décommenter `migrate(...)` n'est pas encore possible. Avant de commiter, neutralise-le par :

```ts
// await migrate(handle.db, { migrationsFolder: MIGRATIONS_FOLDER });
// Réactivé Task 6 step 6.4 quand la première migration existe.
```

Run: `pnpm --filter @piloo/db-schema test`
Expected: PASS (le SELECT 1 réussit).

- [ ] **Step 2.7 — Supprimer `setup.test.ts` (test smoke jetable)**

```bash
rm packages/db-schema/test/setup.test.ts
```

- [ ] **Step 2.8 — Commit**

```bash
git add packages/db-schema/test/setup.ts packages/db-schema/src/schema/index.ts
git rm packages/db-schema/src/schema/.gitkeep
git commit -m "feat(db): test setup avec testcontainers Postgres jetable (#32)"
```

---

## Task 3 : Schema `users` + tests d'invariants

**Files:**

- Create: `packages/db-schema/src/schema/users.ts`
- Modify: `packages/db-schema/src/schema/index.ts`
- Create: `packages/db-schema/test/users.test.ts`

- [ ] **Step 3.1 — Tests d'invariants users (failing)**

```ts
// packages/db-schema/test/users.test.ts
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { users, type NewUser } from '../src/schema/index.ts';
import { setupTestDb, truncateAll, type TestDb } from './setup.ts';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 60_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await truncateAll(env.handle);
});

const baseUser = (overrides: Partial<NewUser> = {}): NewUser => ({
  email: 'a@b.fr',
  passwordHash: 'hash',
  nom: 'Dupont',
  prenom: 'Marie',
  typeCompte: 'particulier',
  ...overrides,
});

describe('users', () => {
  it('insère un user particulier minimal', async () => {
    const [row] = await env.handle.db.insert(users).values(baseUser()).returning();
    expect(row?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(row?.email).toBe('a@b.fr');
    expect(row?.preferences).toEqual({});
    expect(row?.deletedAt).toBeNull();
    expect(row?.createdAt).toBeInstanceOf(Date);
  });

  it('rejette un email dupliqué (unique)', async () => {
    await env.handle.db.insert(users).values(baseUser({ email: 'dup@b.fr' }));
    await expect(
      env.handle.db.insert(users).values(baseUser({ email: 'dup@b.fr' })),
    ).rejects.toThrow(/duplicate key|users_email/);
  });

  it('rejette un type_compte invalide (enum)', async () => {
    await expect(
      // @ts-expect-error type narrowed by enum, on teste runtime
      env.handle.db.insert(users).values(baseUser({ typeCompte: 'admin' })),
    ).rejects.toThrow(/invalid input value for enum/);
  });

  it('soft-delete : la ligne reste visible avec deletedAt non null', async () => {
    const [inserted] = await env.handle.db.insert(users).values(baseUser()).returning();
    const id = inserted?.id;
    if (!id) throw new Error('insert failed');
    await env.handle.client`UPDATE users SET deleted_at = now() WHERE id = ${id}`;
    const rows = await env.handle.client`SELECT id, deleted_at FROM users WHERE id = ${id}`;
    expect(rows[0]?.deleted_at).toBeInstanceOf(Date);
  });
});
```

- [ ] **Step 3.2 — Run, vérifier l'échec**

Run: `pnpm --filter @piloo/db-schema test test/users.test.ts`
Expected: échec sur `users` import (pas encore défini) ou sur l'absence de table.

- [ ] **Step 3.3 — Implémenter le schéma users**

```ts
// packages/db-schema/src/schema/users.ts
// Source : docs/data-model.md §"users". Compte de connexion + profil minimal.
// Les préférences (notifs, langue, fuseau) vivent dans `preferences` JSONB
// pour éviter de migrer la DB à chaque ajout de prefs.
import { sql } from 'drizzle-orm';
import {
  index,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

export const typeCompteEnum = pgEnum('type_compte', ['particulier', 'pro']);

export const users = pgTable(
  'users',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    email: text().notNull(),
    passwordHash: text().notNull(),
    emailVerifiedAt: timestamp({ withTimezone: true }),
    nom: text().notNull(),
    prenom: text().notNull(),
    typeCompte: typeCompteEnum().notNull(),
    telephone: text(),
    preferences: jsonb().notNull().default({}),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
    lastLoginAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    uniqueIndex('idx_users_email').on(table.email),
    index('idx_users_deleted_at')
      .on(table.deletedAt)
      .where(sql`${table.deletedAt} IS NOT NULL`),
  ],
);

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
```

- [ ] **Step 3.4 — Mettre à jour le barrel**

```ts
// packages/db-schema/src/schema/index.ts
export * from './users.ts';
```

- [ ] **Step 3.5 — Générer la migration partielle (juste users)**

Run: `pnpm db:generate`
Expected: création de `packages/db-schema/migrations/0000_<adjectif>_<nom>.sql` contenant `CREATE TYPE type_compte`, `CREATE TABLE users`, `CREATE UNIQUE INDEX idx_users_email`, `CREATE INDEX idx_users_deleted_at`.

> Si tu vois un message du genre "DATABASE_URL non défini — migrate échouera tant qu'il manque" — c'est OK, `generate` ne se connecte pas, c'est juste un warning du bloc en haut de `drizzle.config.ts`.

- [ ] **Step 3.6 — Réactiver `migrate(...)` dans `test/setup.ts`**

```ts
// packages/db-schema/test/setup.ts
await migrate(handle.db, { migrationsFolder: MIGRATIONS_FOLDER });
```

- [ ] **Step 3.7 — Run tests users**

Run: `pnpm --filter @piloo/db-schema test test/users.test.ts`
Expected: les 4 tests passent.

- [ ] **Step 3.8 — Commit (sans la migration encore — voir Task 6)**

> ⚠️ La migration sera supprimée + régénérée à la Task 6 quand les 3 tables seront posées. On ne la commit pas maintenant pour éviter une migration "users seul" suivie d'une migration "ajouter officines+partages" — un seul `0000_*.sql` initial est plus propre.

```bash
rm -rf packages/db-schema/migrations
git add packages/db-schema/src/schema/users.ts packages/db-schema/src/schema/index.ts packages/db-schema/test/users.test.ts packages/db-schema/test/setup.ts
git commit -m "feat(db): schéma users + tests d'invariants (#32)"
```

---

## Task 4 : Schema `officines` + tests

**Files:**

- Create: `packages/db-schema/src/schema/officines.ts`
- Modify: `packages/db-schema/src/schema/index.ts`
- Create: `packages/db-schema/test/officines.test.ts`

- [ ] **Step 4.1 — Tests d'invariants officines (failing)**

```ts
// packages/db-schema/test/officines.test.ts
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { officines, users, type NewOfficine, type NewUser } from '../src/schema/index.ts';
import { setupTestDb, truncateAll, type TestDb } from './setup.ts';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 60_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await truncateAll(env.handle);
});

async function insertUser(overrides: Partial<NewUser> = {}) {
  const [u] = await env.handle.db
    .insert(users)
    .values({
      email: `u${String(Math.random()).slice(2, 8)}@b.fr`,
      passwordHash: 'hash',
      nom: 'Test',
      prenom: 'User',
      typeCompte: 'particulier',
      ...overrides,
    })
    .returning();
  if (!u) throw new Error('insert user failed');
  return u;
}

describe('officines', () => {
  it('insère une officine perso liée à un user', async () => {
    const u = await insertUser();
    const [o] = await env.handle.db
      .insert(officines)
      .values({
        nom: 'Maison',
        type: 'perso',
        proprietaireUserId: u.id,
      } satisfies NewOfficine)
      .returning();
    expect(o?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(o?.proprietaireUserId).toBe(u.id);
    expect(o?.type).toBe('perso');
    expect(o?.deletedAt).toBeNull();
  });

  it('rejette une officine sans propriétaire (FK violation)', async () => {
    await expect(
      env.handle.db.insert(officines).values({
        nom: 'Ghost',
        type: 'perso',
        // FK vers un user qui n'existe pas
        proprietaireUserId: '00000000-0000-0000-0000-000000000000',
      } satisfies NewOfficine),
    ).rejects.toThrow(/foreign key|fk_officines/);
  });

  it('rejette un type invalide', async () => {
    const u = await insertUser();
    await expect(
      env.handle.db.insert(officines).values({
        nom: 'Bad',
        // @ts-expect-error enum runtime test
        type: 'inconnu',
        proprietaireUserId: u.id,
      }),
    ).rejects.toThrow(/invalid input value for enum/);
  });

  it("soft-delete : la ligne reste, peut être recréée à l'identique", async () => {
    const u = await insertUser();
    const [o] = await env.handle.db
      .insert(officines)
      .values({ nom: 'A', type: 'perso', proprietaireUserId: u.id })
      .returning();
    await env.handle.client`UPDATE officines SET deleted_at = now() WHERE id = ${o!.id}`;

    // On peut recréer une autre officine du même propriétaire — pas de unique sur proprietaire_user_id.
    const [o2] = await env.handle.db
      .insert(officines)
      .values({ nom: 'A', type: 'perso', proprietaireUserId: u.id })
      .returning();
    expect(o2?.id).not.toBe(o?.id);
  });
});
```

- [ ] **Step 4.2 — Run, vérifier l'échec**

Run: `pnpm --filter @piloo/db-schema test test/officines.test.ts`
Expected: échec — `officines` n'est pas exporté.

- [ ] **Step 4.3 — Implémenter le schéma officines**

```ts
// packages/db-schema/src/schema/officines.ts
// Source : docs/data-model.md §"officines". Conteneur logique des boîtes.
// Une officine perso est créée auto au signup particulier (#69), une officine
// patient est créée à la demande par les comptes pro.
import { date, index, pgEnum, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.ts';

export const typeOfficineEnum = pgEnum('type_officine', ['perso', 'patient']);

export const officines = pgTable(
  'officines',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    nom: text().notNull(),
    type: typeOfficineEnum().notNull(),
    // ON DELETE RESTRICT : on n'autorise pas la suppression d'un user qui
    // possède des officines (utiliser soft-delete + reassignation amont).
    proprietaireUserId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    dateNaissance: date(),
    notes: text(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [index('idx_officines_proprietaire').on(table.proprietaireUserId)],
);

export type Officine = typeof officines.$inferSelect;
export type NewOfficine = typeof officines.$inferInsert;
```

- [ ] **Step 4.4 — Mettre à jour le barrel**

```ts
// packages/db-schema/src/schema/index.ts
export * from './users.ts';
export * from './officines.ts';
```

- [ ] **Step 4.5 — Régénérer la migration**

```bash
rm -rf packages/db-schema/migrations
pnpm db:generate
```

Vérifie le SQL : `CREATE TYPE type_officine`, `CREATE TABLE officines`, `idx_officines_proprietaire`, FK vers `users(id) ON DELETE RESTRICT`.

- [ ] **Step 4.6 — Run tests officines**

Run: `pnpm --filter @piloo/db-schema test test/officines.test.ts`
Expected: les 4 tests passent.

- [ ] **Step 4.7 — Commit**

```bash
rm -rf packages/db-schema/migrations
git add packages/db-schema/src/schema/officines.ts packages/db-schema/src/schema/index.ts packages/db-schema/test/officines.test.ts
git commit -m "feat(db): schéma officines + tests FK + soft-delete (#32)"
```

---

## Task 5 : Schema `partages` + tests (partial unique + reinsert)

**Files:**

- Create: `packages/db-schema/src/schema/partages.ts`
- Modify: `packages/db-schema/src/schema/index.ts`
- Create: `packages/db-schema/test/partages.test.ts`

- [ ] **Step 5.1 — Tests d'invariants partages (failing)**

```ts
// packages/db-schema/test/partages.test.ts
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { officines, partages, users, type NewPartage } from '../src/schema/index.ts';
import { setupTestDb, truncateAll, type TestDb } from './setup.ts';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 60_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await truncateAll(env.handle);
});

async function fixture() {
  const [owner] = await env.handle.db
    .insert(users)
    .values({
      email: `o${String(Math.random()).slice(2, 8)}@b.fr`,
      passwordHash: 'h',
      nom: 'O',
      prenom: 'O',
      typeCompte: 'particulier',
    })
    .returning();
  const [editor] = await env.handle.db
    .insert(users)
    .values({
      email: `e${String(Math.random()).slice(2, 8)}@b.fr`,
      passwordHash: 'h',
      nom: 'E',
      prenom: 'E',
      typeCompte: 'particulier',
    })
    .returning();
  const [officine] = await env.handle.db
    .insert(officines)
    .values({ nom: 'Maison', type: 'perso', proprietaireUserId: owner!.id })
    .returning();
  return { owner: owner!, editor: editor!, officine: officine! };
}

describe('partages', () => {
  it('insère un partage owner', async () => {
    const f = await fixture();
    const [p] = await env.handle.db
      .insert(partages)
      .values({
        officineId: f.officine.id,
        userId: f.owner.id,
        role: 'owner',
        invitedBy: null,
        invitedAt: new Date(),
        acceptedAt: new Date(),
      } satisfies NewPartage)
      .returning();
    expect(p?.role).toBe('owner');
  });

  it('rejette un duplicate (officine_id, user_id) actif', async () => {
    const f = await fixture();
    await env.handle.db.insert(partages).values({
      officineId: f.officine.id,
      userId: f.editor.id,
      role: 'editor',
      invitedAt: new Date(),
    });
    await expect(
      env.handle.db.insert(partages).values({
        officineId: f.officine.id,
        userId: f.editor.id,
        role: 'viewer',
        invitedAt: new Date(),
      }),
    ).rejects.toThrow(/duplicate key|partages_officine_user/);
  });

  it('autorise un nouveau partage après soft-delete du précédent', async () => {
    const f = await fixture();
    const [p1] = await env.handle.db
      .insert(partages)
      .values({
        officineId: f.officine.id,
        userId: f.editor.id,
        role: 'editor',
        invitedAt: new Date(),
      })
      .returning();
    await env.handle.client`UPDATE partages SET deleted_at = now() WHERE id = ${p1!.id}`;
    // Doit fonctionner — le partial unique exclut deleted_at IS NOT NULL.
    const [p2] = await env.handle.db
      .insert(partages)
      .values({
        officineId: f.officine.id,
        userId: f.editor.id,
        role: 'viewer',
        invitedAt: new Date(),
      })
      .returning();
    expect(p2?.role).toBe('viewer');
  });

  it('rejette un rôle invalide', async () => {
    const f = await fixture();
    await expect(
      env.handle.db.insert(partages).values({
        officineId: f.officine.id,
        userId: f.editor.id,
        // @ts-expect-error
        role: 'admin',
        invitedAt: new Date(),
      }),
    ).rejects.toThrow(/invalid input value for enum/);
  });
});
```

- [ ] **Step 5.2 — Run, vérifier l'échec**

Run: `pnpm --filter @piloo/db-schema test test/partages.test.ts`
Expected: échec — `partages` n'existe pas encore.

- [ ] **Step 5.3 — Implémenter le schéma partages**

```ts
// packages/db-schema/src/schema/partages.ts
// Source : docs/data-model.md §"partages". Many-to-many users ↔ officines avec rôle.
// Le partial unique (officine_id, user_id) WHERE deleted_at IS NULL permet
// de garder l'historique des partages révoqués sans bloquer une réinvitation.
import { sql } from 'drizzle-orm';
import { pgEnum, pgTable, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { officines } from './officines.ts';
import { users } from './users.ts';

export const roleEnum = pgEnum('role_partage', ['owner', 'editor', 'viewer']);

export const partages = pgTable(
  'partages',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    officineId: uuid()
      .notNull()
      .references(() => officines.id, { onDelete: 'restrict' }),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    role: roleEnum().notNull(),
    invitedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    invitedAt: timestamp({ withTimezone: true }).notNull(),
    acceptedAt: timestamp({ withTimezone: true }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    uniqueIndex('partages_officine_user_unique')
      .on(table.officineId, table.userId)
      .where(sql`${table.deletedAt} IS NULL`),
  ],
);

export type Partage = typeof partages.$inferSelect;
export type NewPartage = typeof partages.$inferInsert;
```

- [ ] **Step 5.4 — Mettre à jour le barrel**

```ts
// packages/db-schema/src/schema/index.ts
export * from './users.ts';
export * from './officines.ts';
export * from './partages.ts';
```

- [ ] **Step 5.5 — Régénérer la migration**

```bash
rm -rf packages/db-schema/migrations
pnpm db:generate
```

Vérifie le SQL : `CREATE TYPE role_partage`, `CREATE TABLE partages`, FKs vers `officines` et `users`, `CREATE UNIQUE INDEX partages_officine_user_unique ... WHERE "deleted_at" IS NULL`.

- [ ] **Step 5.6 — Run tests partages**

Run: `pnpm --filter @piloo/db-schema test test/partages.test.ts`
Expected: les 4 tests passent.

- [ ] **Step 5.7 — Commit**

```bash
rm -rf packages/db-schema/migrations
git add packages/db-schema/src/schema/partages.ts packages/db-schema/src/schema/index.ts packages/db-schema/test/partages.test.ts
git commit -m "feat(db): schéma partages + tests partial unique + reinsert (#32)"
```

---

## Task 6 : Migration finale + tests end-to-end

**Files:**

- Create: `packages/db-schema/migrations/0000_*.sql` (généré)
- Create: `packages/db-schema/migrations/meta/*` (généré)

- [ ] **Step 6.1 — Générer la migration consolidée**

```bash
rm -rf packages/db-schema/migrations
pnpm db:generate
```

Le résultat doit contenir, dans un seul fichier `0000_<adj>_<nom>.sql` :

1. `CREATE TYPE type_compte`, `CREATE TYPE type_officine`, `CREATE TYPE role_partage`
2. `CREATE TABLE users` + index
3. `CREATE TABLE officines` + FK + index
4. `CREATE TABLE partages` + FKs + unique index partial

- [ ] **Step 6.2 — Inspecter le SQL et corriger l'ordre si besoin**

Drizzle-kit ordonne par dépendances de FK. Vérifie `users` avant `officines` avant `partages`. Si l'ordre est inversé, c'est un bug à signaler — fallback : éditer le SQL à la main (cas ultra rare).

- [ ] **Step 6.3 — Faire tourner toute la suite de tests**

Run: `pnpm --filter @piloo/db-schema test`
Expected: 12 tests passent (4 par suite × 3 suites).

- [ ] **Step 6.4 — Vérifier que `migrate(...)` est bien actif dans `test/setup.ts`**

Si tu l'avais commenté à la Task 2 step 2.6, décommente-le. Re-run les tests.

- [ ] **Step 6.5 — Vérifier `pnpm openapi:check` (vide attendu) + `pnpm typecheck` + `pnpm lint`**

```bash
pnpm typecheck
pnpm lint
pnpm openapi:check
```

Tous verts attendus.

- [ ] **Step 6.6 — Commit la migration**

```bash
git add packages/db-schema/migrations
git commit -m "chore(db): génère 0000_initial.sql (users + officines + partages) (#32)"
```

---

## Task 7 : PR + clôture du ticket

- [ ] **Step 7.1 — Push la branche**

```bash
git push -u origin feat/32-tables-users-officines-partages
```

- [ ] **Step 7.2 — Ouvrir la PR**

```bash
gh pr create --base main --title "feat(db): tables users + officines + partages (#32)" --body "$(cat <<'EOF'
## Summary

Closes #32.

- Premiers schémas Drizzle réels (users, officines, partages) — basés sur \`docs/data-model.md\`.
- Soft-delete enforced (\`deleted_at\` nullable sur les 3 tables).
- Index :
  - \`idx_users_email\` (unique), \`idx_users_deleted_at\` (partiel sur deleted_at NOT NULL).
  - \`idx_officines_proprietaire\`.
  - \`partages_officine_user_unique\` (partial unique sur (officine_id, user_id) WHERE deleted_at IS NULL).
- 12 tests d'invariants (Vitest + testcontainers Postgres jetable) :
  - users : insert minimal, email unique, enum type_compte, soft-delete.
  - officines : insert avec FK, FK violation rejetée, enum type, soft-delete + recreate.
  - partages : insert owner, duplicate (officine_id, user_id) actif rejeté, reinsert après soft-delete OK, enum role.
- Migration \`0000_*.sql\` générée et committée.
- Factory \`createDb(url)\` exposée pour les tests + futures API routes.

## Décisions

- **testcontainers** plutôt que GHA postgres service : zéro config locale ni CI, container jetable par suite, fidèle à un Postgres réel.
- **Partial unique sur partages** plutôt que delete + reinsert hard : on garde l'historique des partages révoqués (utile pour audit + dashboard pro).
- **ON DELETE RESTRICT** sur les FKs métier : pas de cascade qui ferait disparaître silencieusement les données. Suppressions = soft-delete amont.

## Test plan

- [x] \`pnpm --filter @piloo/db-schema test\` → 12 tests passent localement (testcontainers tire postgres:16-alpine).
- [x] \`pnpm typecheck\` / \`pnpm lint\` / \`pnpm openapi:check\` verts.
- [ ] CI verte.

## Suites

Débloque #36 (seed dev), #69 (auto-création officine), #70 (API CRUD officines), #119 (matrice RBAC), et toutes les tables enfants (#33 boites, #34 ordonnances, #35 alertes/pending_operations).
EOF
)"
```

- [ ] **Step 7.3 — Attendre la CI puis merger**

```bash
until gh pr checks $(gh pr view --json number --jq '.number') 2>&1 | grep -qE 'fail|pass'; do sleep 10; done
gh pr checks $(gh pr view --json number --jq '.number')
```

Si vert :

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 7.4 — Wrap-up commentaire sur le ticket**

```bash
gh issue comment 32 --body "✅ Mergé. Schémas users + officines + partages + migration 0000 + 12 tests d'invariants (testcontainers). Débloque #36, #69, #70, #119 et les tables enfants (#33, #34, #35)."
```

- [ ] **Step 7.5 — Vérifier que le ticket est bien CLOSED**

```bash
gh issue view 32 --json state --jq '.state'
```

Expected: `CLOSED` (auto-fermé par le `Closes #32`).

---

## Risques connus / fallbacks

- **testcontainers + Docker absent** : le `setupTestDb()` échoue avec un message clair. Fallback : ajouter un mode dégradé qui lit `TEST_DATABASE_URL` (déjà supporté trivialement en remplaçant `setupTestDb()`). À ne faire **que si** Docker n'est vraiment pas dispo en CI ; sinon overkill.
- **Le warning "DATABASE_URL non défini"** dans `drizzle.config.ts` peut spammer la console pendant `pnpm db:generate`. Si c'est gênant : conditionner le warn sur `process.env.NODE_ENV !== 'test'` ET `process.env.DRIZZLE_KIT_GENERATE !== '1'`.
- **`sql\`...IS NULL\``** dans le partial unique : l'API exacte de Drizzle 0.36 utilise `sql` template tag — vérifié dans la doc. Si ça ne marche pas, fallback : écrire l'index dans la migration SQL à la main et marquer la table avec `--bigint-mode disable` ; mais ne pas faire ça avant d'avoir constaté l'échec.
- **`crypto.randomUUID()`** : disponible globalement en Node 22+. OK puisque CI = Node 22.
