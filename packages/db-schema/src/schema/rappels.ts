// Rappels simples sans ordonnance (#327).
//
// Cas d'usage : la pilule contraceptive, vitamine D quotidienne,
// supplément… L'user veut juste un "ping à 8h tous les jours" sans
// passer par toute la chaîne Ordonnance → Prescription → Prises
// planifiées qui suppose un cadre prescrit.
//
// Différences avec prises_planifiees :
//  - Pas de prescription_id (autonome).
//  - Pas d'occurrences générées en base : c'est un *pattern* récurrent,
//    pas une liste de prises. Les notifs sont schedulées localement
//    côté mobile (flutter_local_notifications) pour éviter d'inonder
//    la DB avec une ligne par occurrence.
//  - Pas de validation/statut "pris/sauté" — c'est un aide-mémoire,
//    pas un tracking de compliance.
//
// MVP : daily uniquement. La récurrence cyclique (21j/28j pilule)
// arrivera en follow-up — d'où le champ `recurrence_type` qui réserve
// l'évolution.
import { boolean, index, pgEnum, pgTable, text, time, timestamp, uuid } from 'drizzle-orm/pg-core';

import { boites } from './boites.ts';
import { officines } from './officines.ts';
import { users } from './users.ts';

export const recurrenceTypeEnum = pgEnum('rappel_recurrence_type', ['daily']);

export const rappels = pgTable(
  'rappels',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /// Rattache optionnellement à une officine — utile quand on
    /// partagera plus tard les rappels avec d'autres membres (post-MVP).
    /// Null = rappel strictement personnel.
    officineId: uuid().references(() => officines.id, { onDelete: 'set null' }),
    /// Rattache optionnellement à une boîte d'inventaire — l'UI peut
    /// alors afficher "Rappel : Doliprane 1000" + lien vers la fiche.
    /// `set null` car la suppression de la boîte ne doit pas faire
    /// sauter le rappel.
    boiteId: uuid().references(() => boites.id, { onDelete: 'set null' }),
    /// Libellé affiché ("Pilule Yaz", "Vitamine D"). Toujours rempli
    /// même si boite_id est posé — l'user peut vouloir un libellé
    /// différent de la dénomination BDPM (ex: "Pilule du matin").
    label: text().notNull(),
    /// Heure de déclenchement (timezone user, gérée côté client).
    /// `time` Postgres = HH:MM:SS sans timezone.
    heure: time().notNull(),
    recurrenceType: recurrenceTypeEnum().notNull().default('daily'),
    actif: boolean().notNull().default(true),
    notes: text(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    // Lookup principal : "tous les rappels actifs d'un user pour les
    // re-scheduler au launch app".
    index('idx_rappels_user_actif').on(table.userId, table.actif),
  ],
);

export type Rappel = typeof rappels.$inferSelect;
export type NewRappel = typeof rappels.$inferInsert;
