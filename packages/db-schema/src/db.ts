// packages/db-schema/src/db.ts
// Factory partagée : tests + (plus tard) API routes Next.js construisent leur
// client Drizzle via createDb(url). On ne réexporte pas un singleton — chaque
// caller gère son propre cycle de vie (close() après usage).
import { drizzle, type PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import postgres, { type Sql } from 'postgres';

import * as schema from './schema/index.ts';

// Postgres OIDs for timestamp types. Used to restore custom parsers after
// drizzle() overwrites them (see createDb below).
const PG_OID_TIMESTAMP = 1114; // timestamp without time zone
const PG_OID_TIMESTAMPTZ = 1184; // timestamp with time zone

export type Db = PostgresJsDatabase<typeof schema>;

export interface DbHandle {
  readonly db: Db;
  readonly client: Sql;
  close: () => Promise<void>;
}

export function createDb(url: string): DbHandle {
  // idle_timeout ferme les connexions inactives au bout de 20 s : indispensable
  // sur un compute Neon-like (l'autosuspend exige 0 connexion ouverte, sinon le
  // compute tourne 24/7 — cf. #357) et sain partout ailleurs.
  const client = postgres(url, { max: 5, idle_timeout: 20, prepare: false });
  // drizzle() overwrites timestamp parsers (OIDs 1114, 1184) with identity
  // functions so it can handle deserialization itself in its session layer.
  // We restore them after construction so raw client queries (used in tests
  // and migrations) also get proper Date objects for timestamptz columns.
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const tstzParser = client.options.parsers[PG_OID_TIMESTAMPTZ]!;
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const tsParser = client.options.parsers[PG_OID_TIMESTAMP]!;
  const db = drizzle(client, { schema, casing: 'snake_case' });
  client.options.parsers[PG_OID_TIMESTAMPTZ] = tstzParser;
  client.options.parsers[PG_OID_TIMESTAMP] = tsParser;
  return {
    db,
    client,
    close: async () => {
      await client.end({ timeout: 5 });
    },
  };
}
