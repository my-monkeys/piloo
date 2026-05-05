// packages/db-schema/src/schema/ordonnances.ts
// Source : docs/data-model.md §"ordonnances". Une ordonnance regroupe les
// prescriptions saisies pour une officine (manuel ou OCR à terme). Soft delete
// uniquement — la cascade soft-delete vers prescriptions/prises est gérée au
// niveau service (FKs en RESTRICT pour bloquer toute suppression dure).
import { date, index, pgEnum, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { officines } from './officines.ts';
import { users } from './users.ts';

export const sourceOrdonnanceEnum = pgEnum('source_ordonnance', ['manuelle', 'ocr']);

export const ordonnances = pgTable(
  'ordonnances',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    officineId: uuid()
      .notNull()
      .references(() => officines.id, { onDelete: 'restrict' }),
    prescripteur: text(),
    datePrescription: date().notNull(),
    source: sourceOrdonnanceEnum().notNull().default('manuelle'),
    photoUrl: text(),
    notes: text(),
    saisiePar: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [index('idx_ordonnances_officine').on(table.officineId)],
);

export type Ordonnance = typeof ordonnances.$inferSelect;
export type NewOrdonnance = typeof ordonnances.$inferInsert;
