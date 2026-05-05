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
