// packages/db-schema/test/setup.ts
// Lance un Postgres jetable via testcontainers, applique les migrations Drizzle,
// expose un DbHandle. Appelé en beforeAll dans chaque suite. Idempotent — un
// container par suite, teardown obligatoire en afterAll.
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

import { createDb, type DbHandle } from '../src/db.ts';

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

export async function truncateAll(handle: DbHandle): Promise<void> {
  // CASCADE couvre les FKs.
  // Liste de la plus dépendante à la moins dépendante par convention.
  await handle.client`TRUNCATE TABLE prises_planifiees, prescriptions, ordonnances, boites, partages, officines, users, medicaments_bdpm RESTART IDENTITY CASCADE`;
}
