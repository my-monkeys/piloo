// packages/db-schema/test/setup.ts
// Lance un Postgres jetable via testcontainers, applique les migrations Drizzle,
// expose un DbHandle. Appelé en beforeAll dans chaque suite. Idempotent — un
// container par suite, teardown obligatoire en afterAll.
//
// Task 6 step 6.4 : décommenter les 4 lignes suivantes pour activer les migrations.
// import { migrate } from 'drizzle-orm/postgres-js/migrator';
// import { dirname, resolve } from 'node:path';
// import { fileURLToPath } from 'node:url';
// const MIGRATIONS_FOLDER = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'migrations');

import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

import { createDb, type DbHandle } from '../src/db.ts';

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

  // await migrate(handle.db, { migrationsFolder: MIGRATIONS_FOLDER });
  // Réactivé Task 6 step 6.4 quand la première migration existe.

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
