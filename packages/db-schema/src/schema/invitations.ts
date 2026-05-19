// packages/db-schema/src/schema/invitations.ts
// Invitations partage officine (#123).
//
// Une invitation = lien expirable (72h par défaut) qu'un owner envoie à
// quelqu'un pour rejoindre son officine avec un rôle prédéfini. À
// l'acceptation, on insère une ligne `partages` correspondante.
//
// Sécurité : l'ID UUIDv4 sert de token (128 bits aléatoires, suffisant
// — pas de besoin de signature). Le token est mis dans une URL publique
// → l'attaquant doit deviner l'UUID pour acceder.
//
// Cycle de vie :
//   created → pending → accepted (acceptedAt non null)
//                    └→ revoked  (deletedAt non null avant acceptation)
//                    └→ expired  (now > expiresAt, jamais accepté)
//
// Soft-delete : on garde l'historique des invitations rejetées /
// révoquées pour les audits (#161 audit RGPD).
import { index, pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

import { officines } from './officines.ts';
import { roleEnum } from './partages.ts';
import { users } from './users.ts';

export const invitations = pgTable(
  'invitations',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    officineId: uuid()
      .notNull()
      .references(() => officines.id, { onDelete: 'restrict' }),
    role: roleEnum().notNull(),
    invitedByUserId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    /** Pré-rempli optionnel — sert juste à afficher l'email à
     *  l'accepteur. La vraie vérification d'identité = auth Better Auth. */
    email: text(),
    expiresAt: timestamp({ withTimezone: true }).notNull(),
    acceptedAt: timestamp({ withTimezone: true }),
    acceptedByUserId: uuid().references(() => users.id, { onDelete: 'set null' }),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    index('idx_invitations_officine').on(table.officineId),
    index('idx_invitations_expires').on(table.expiresAt),
  ],
);

export type Invitation = typeof invitations.$inferSelect;
export type NewInvitation = typeof invitations.$inferInsert;
