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
