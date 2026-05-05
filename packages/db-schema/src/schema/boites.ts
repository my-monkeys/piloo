// packages/db-schema/src/schema/boites.ts
// Source : docs/data-model.md §"boites". Boîtes physiques scannées dans une officine.
// Deux index uniques partiels : avec numero_serie (datamatrix GS1 récent) et
// fallback (officine, cip13, lot) pour les vieilles boîtes sans série mais
// avec lot. Si lot ET serie sont NULL on n'impose rien (vieilles boîtes
// non identifiables).
import { sql } from 'drizzle-orm';
import {
  date,
  index,
  integer,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import { officines } from './officines.ts';
import { users } from './users.ts';

export const statutBoiteEnum = pgEnum('statut_boite', ['active', 'vide', 'perimee']);

export const boites = pgTable(
  'boites',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    officineId: uuid()
      .notNull()
      .references(() => officines.id, { onDelete: 'restrict' }),
    cip13: text().notNull(),
    lot: text(),
    numeroSerie: text(),
    peremption: date().notNull(),
    unitesInitiales: integer(),
    unitesRestantes: integer(),
    statut: statutBoiteEnum().notNull().default('active'),
    notes: text(),
    ajouteePar: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    uniqueIndex('boites_officine_cip13_lot_serie_unique')
      .on(table.officineId, table.cip13, table.lot, table.numeroSerie)
      .where(sql`${table.deletedAt} IS NULL AND ${table.numeroSerie} IS NOT NULL`),
    uniqueIndex('boites_officine_cip13_lot_unique')
      .on(table.officineId, table.cip13, table.lot)
      .where(
        sql`${table.deletedAt} IS NULL AND ${table.numeroSerie} IS NULL AND ${table.lot} IS NOT NULL`,
      ),
    index('idx_boites_officine_statut').on(table.officineId, table.statut),
    index('idx_boites_cip13').on(table.cip13),
    index('idx_boites_peremption').on(table.peremption),
  ],
);

export type Boite = typeof boites.$inferSelect;
export type NewBoite = typeof boites.$inferInsert;
