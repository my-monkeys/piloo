// packages/db-schema/src/schema/officines.ts
// Source : docs/data-model.md §"officines". Conteneur logique des boîtes.
// Une officine perso est créée auto au signup particulier (#69), une officine
// patient est créée à la demande par les comptes pro.
import { date, index, pgEnum, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.ts';

export const typeOfficineEnum = pgEnum('type_officine', ['perso', 'patient']);

export const officines = pgTable(
  'officines',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    nom: text().notNull(),
    type: typeOfficineEnum().notNull(),
    // ON DELETE RESTRICT : on n'autorise pas la suppression d'un user qui
    // possède des officines (utiliser soft-delete + reassignation amont).
    proprietaireUserId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    dateNaissance: date(),
    notes: text(),
    // Fuseau IANA du carnet (source de vérité pour planifier/afficher les
    // prises). Défaut Europe/Paris pour les officines existantes (#363).
    timezone: text().notNull().default('Europe/Paris'),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [index('idx_officines_proprietaire').on(table.proprietaireUserId)],
);

export type Officine = typeof officines.$inferSelect;
export type NewOfficine = typeof officines.$inferInsert;
