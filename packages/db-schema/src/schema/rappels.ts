// packages/db-schema/src/schema/rappels.ts
// Rappels rapides sur un médicament, sans passer par une ordonnance.
// L'utilisateur configure depuis l'écran officine (modale quick-actions
// d'une boîte) : matin/midi/soir/coucher × quantité par moment.
// Distinct de `prescriptions` qui restent attachées à une ordonnance
// (carnet d'ordonnance scannée). Un rappel = pour soi-même, sans
// validation médicale derrière.
//
// Conséquence : on N'écrit PAS dans `prises_planifiees` depuis un
// rappel pour ce premier ship. La génération automatique de prises
// + notifications locales = ticket de suivi (à découper séparément).
import { boolean, date, index, integer, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { officines } from './officines.ts';
import { users } from './users.ts';

export const rappels = pgTable(
  'rappels',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    officineId: uuid()
      .notNull()
      .references(() => officines.id, { onDelete: 'restrict' }),
    cip13: text().notNull(),
    /// Snapshot du nom à la création (résolu via BDPM ou saisi manuellement).
    /// On le garde côté rappel pour ne pas dépendre d'un join BDPM à
    /// chaque affichage timeline.
    nomTexte: text().notNull(),
    /// Unité affichée — "comprimé", "gélule", "goutte", "mL"…
    /// Par défaut "comprimé" si l'app ne sait pas. Texte libre court.
    unite: text().notNull().default('comprimé'),
    /// Quantité à prendre à chaque moment. null = pas de prise ce
    /// moment-là (pas 0, qui voudrait dire "0 comprimé prescrit").
    quantiteMatin: integer(),
    quantiteMidi: integer(),
    quantiteSoir: integer(),
    quantiteCoucher: integer(),
    /// Période d'application du rappel.
    dateDebut: date().notNull(),
    /// null = rappel sans fin (cas chronique). La timeline s'arrête
    /// de générer les prises à partir de date_fin + 1 jour.
    dateFin: date(),
    /// Permet de mettre en pause un rappel sans le supprimer (ex:
    /// arrêt temporaire prescrit par le médecin). UI fournira un
    /// toggle, on n'a pas besoin de soft-delete + recréer.
    actif: boolean().notNull().default(true),
    notes: text(),
    creeParUserId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    index('idx_rappels_officine_actif').on(table.officineId, table.actif),
    index('idx_rappels_cip13').on(table.cip13),
  ],
);

export type Rappel = typeof rappels.$inferSelect;
export type NewRappel = typeof rappels.$inferInsert;
