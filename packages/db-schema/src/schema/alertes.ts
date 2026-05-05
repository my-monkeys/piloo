// packages/db-schema/src/schema/alertes.ts
// Source : docs/data-model.md §"alertes" + docs/spec.md §6.1.
// Une ligne = une alerte adressée à un user pour une officine donnée. Le
// payload JSONB porte le contexte (boite_id, prescription_id, jours_restants,
// ...) selon le type. La règle "qui est destinataire" (propriétaire vs
// éditeurs) est appliquée au niveau service au moment de la création — la
// table stocke déjà le user résolu.
import { sql } from 'drizzle-orm';
import { index, jsonb, pgEnum, pgTable, timestamp, uuid } from 'drizzle-orm/pg-core';

import { officines } from './officines.ts';
import { users } from './users.ts';

export const typeAlerteEnum = pgEnum('type_alerte', [
  'peremption_30j',
  'peremption_7j',
  'stock_bas',
  'prise_oubliee',
  'manque_signale',
]);

export type AlertePayload = Record<string, unknown>;

export const alertes = pgTable(
  'alertes',
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
    type: typeAlerteEnum().notNull(),
    payload: jsonb().$type<AlertePayload>().notNull(),
    lueA: timestamp({ withTimezone: true }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    index('idx_alertes_user_non_lues')
      .on(table.userId, table.createdAt)
      .where(sql`${table.lueA} IS NULL AND ${table.deletedAt} IS NULL`),
    index('idx_alertes_user_lue_a').on(table.userId, table.lueA),
  ],
);

export type Alerte = typeof alertes.$inferSelect;
export type NewAlerte = typeof alertes.$inferInsert;
