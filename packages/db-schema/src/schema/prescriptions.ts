// packages/db-schema/src/schema/prescriptions.ts
// Source : docs/data-model.md §"prescriptions". Une ligne d'ordonnance =
// 1 médicament + 1 posologie. La posologie est typée JSONB plutôt qu'éclatée
// en colonnes : le format évolue côté produit et on ne requête jamais sur
// ses champs internes (la timeline lit prises_planifiees, pas la posologie).
import { index, integer, jsonb, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { ordonnances } from './ordonnances.ts';

export interface Posologie {
  unitesParPrise: number;
  unite: string;
  frequence: 'quotidien' | 'hebdomadaire' | 'a_la_demande';
  moments?: readonly ('matin' | 'midi' | 'soir' | 'coucher')[];
  horaires?: readonly string[];
  avecRepas?: boolean;
  espacementMinutes?: number | null;
}

export const prescriptions = pgTable(
  'prescriptions',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    ordonnanceId: uuid()
      .notNull()
      .references(() => ordonnances.id, { onDelete: 'restrict' }),
    cip13: text(),
    cis: text(),
    nomTexte: text().notNull(),
    posologie: jsonb().$type<Posologie>().notNull(),
    dureeJours: integer(),
    indication: text(),
    notes: text(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    index('idx_prescriptions_ordonnance').on(table.ordonnanceId),
    index('idx_prescriptions_cip13').on(table.cip13),
  ],
);

export type Prescription = typeof prescriptions.$inferSelect;
export type NewPrescription = typeof prescriptions.$inferInsert;
