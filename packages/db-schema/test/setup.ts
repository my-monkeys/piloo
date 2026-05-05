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

  // Migration folder is generated cumulatively across Tasks 4-5 and finalized in Task 6.
  // If checking out this branch standalone without running pnpm db:generate first,
  // the migrations folder may be incomplete or missing. Developers should ensure
  // they've run pnpm db:generate to regenerate all pending migrations before running tests.
  // See docs/roadmap.md and packages/db-schema/CLAUDE.md for context.
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
  // CASCADE couvre les FKs (Task 5 ajoute partages).
  // Liste de la plus dépendante à la moins dépendante par convention.
  await handle.client`TRUNCATE TABLE officines, users RESTART IDENTITY CASCADE`;
}
