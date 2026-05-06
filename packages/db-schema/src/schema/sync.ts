// packages/db-schema/src/schema/sync.ts
//
// `sync_operations_log` — journal append-only des opérations push reçues
// du mobile (#92). Sert deux objectifs :
//
//  1. **Idempotence** : `operation_id` est généré côté client (uuid v4),
//     unique sur la table. Rejouer la même opération renvoie le même ack
//     stocké, sans modifier les entités métier.
//  2. **Débogage / audit** : on peut retracer l'historique d'écritures
//     d'un device.
//
// On NE stocke PAS les opérations pull (no-op côté serveur).
import {
  bigint,
  index,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { users } from './users.ts';

export const syncOpStatusEnum = pgEnum('sync_op_status', ['applied', 'conflict', 'rejected']);

export const syncOperationsLog = pgTable(
  'sync_operations_log',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    operationId: text().notNull(), // uuid v4 généré côté client
    clientId: text().notNull(), // identifiant device, débogage
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    type: text().notNull(), // create_boite | update_boite | soft_delete_boite | ...
    entityType: text().notNull(),
    entityId: uuid().notNull(),
    payload: jsonb().notNull(),
    timestampLocal: bigint({ mode: 'number' }).notNull(),
    status: syncOpStatusEnum().notNull(),
    reason: text(), // pour rejected
    serverVersion: jsonb(), // pour conflict : snapshot de l'entité côté serveur
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  },
  (table) => [
    uniqueIndex('idx_sync_op_unique_operation_id').on(table.operationId),
    index('idx_sync_op_user_created').on(table.userId, table.createdAt),
  ],
);

export type SyncOperation = typeof syncOperationsLog.$inferSelect;
export type NewSyncOperation = typeof syncOperationsLog.$inferInsert;
