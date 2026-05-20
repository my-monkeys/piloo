// packages/db-schema/src/schema/prises_planifiees.ts
// Source : docs/data-model.md §"prises_planifiees". Occurrences générées
// depuis une prescription. `officine_id` est dénormalisé pour servir l'index
// timeline `(officine_id, datetime_prevue)` sans avoir à joindre.
// Le passage en `oubliee` se fait par cron (≥1h après horaire prévu, cf. #118).
import { index, pgEnum, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { officines } from './officines.ts';
import { prescriptions } from './prescriptions.ts';
import { users } from './users.ts';

export const statutPriseEnum = pgEnum('statut_prise', ['prevue', 'prise', 'sautee', 'oubliee']);

export const prisesPlanifiees = pgTable(
  'prises_planifiees',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    prescriptionId: uuid()
      .notNull()
      .references(() => prescriptions.id, { onDelete: 'restrict' }),
    officineId: uuid()
      .notNull()
      .references(() => officines.id, { onDelete: 'restrict' }),
    datetimePrevue: timestamp({ withTimezone: true }).notNull(),
    datetimeValidation: timestamp({ withTimezone: true }),
    statut: statutPriseEnum().notNull().default('prevue'),
    valideePar: uuid().references(() => users.id, { onDelete: 'set null' }),
    // Posée par le cron #126 dès qu'un rappel push a été envoyé pour
    // cette prise. Idempotence : un cron qui re-tourne sur la même
    // fenêtre ne renvoie pas la notif (where notified_at is null).
    notifiedAt: timestamp({ withTimezone: true }),
    // Posée par le cron `rappels-retard` (#130) à +30min si la prise
    // n'a toujours pas été validée. Évite le double rappel comme
    // notifiedAt. Distinct de notifiedAt pour permettre les deux
    // rappels (pré-prise + retard).
    lateRemindedAt: timestamp({ withTimezone: true }),
    notes: text(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    index('idx_prises_officine_datetime').on(table.officineId, table.datetimePrevue),
    index('idx_prises_statut_datetime').on(table.statut, table.datetimePrevue),
  ],
);

export type PrisePlanifiee = typeof prisesPlanifiees.$inferSelect;
export type NewPrisePlanifiee = typeof prisesPlanifiees.$inferInsert;
