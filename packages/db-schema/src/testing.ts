// packages/db-schema/src/testing.ts
// Helpers de tests partagés : Postgres jetable via testcontainers, application
// des migrations, truncation idempotente. Importé par les tests d'intégration
// du package lui-même (test/setup.ts) et par ceux des apps qui consomment le
// schéma (apps/web).
//
// Pourquoi ici (sous src/) plutôt que sous test/ : pour pouvoir l'exposer via
// `@piloo/db-schema/testing` aux autres packages du monorepo. Ce module n'est
// pas chargé dans le bundle prod — il importe @testcontainers/postgresql qui
// est dev-only.
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

import { createDb, type DbHandle } from './db.ts';

const MIGRATIONS_FOLDER = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'migrations');

export interface TestDb {
  readonly handle: DbHandle;
  readonly url: string;
  readonly teardown: () => Promise<void>;
}

export async function setupTestDb(): Promise<TestDb> {
  const container: StartedPostgreSqlContainer = await new PostgreSqlContainer('postgres:16-alpine')
    .withDatabase('piloo_test')
    .withUsername('piloo')
    .withPassword('piloo')
    .start();

  try {
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
  } catch (err) {
    await container.stop();
    throw err;
  }
}

// Liste explicite (au lieu de pg_tables) pour rester déterministe et signaler
// quand on oublie d'ajouter une nouvelle table. CASCADE couvre les FKs.
export async function truncateAll(handle: DbHandle): Promise<void> {
  await handle.client`
    TRUNCATE TABLE
      alertes,
      prises_planifiees,
      prescriptions,
      ordonnances,
      boites,
      partages,
      officines,
      sessions,
      accounts,
      verifications,
      users,
      medicaments_bdpm
    RESTART IDENTITY CASCADE
  `;
}
