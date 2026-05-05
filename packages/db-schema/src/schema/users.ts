// packages/db-schema/src/schema/users.ts
// Source : docs/data-model.md §"users". Compte de connexion + profil minimal.
// Les préférences (notifs, langue, fuseau) vivent dans `preferences` JSONB
// pour éviter de migrer la DB à chaque ajout de prefs.
import { sql } from 'drizzle-orm';
import {
  index,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

export const typeCompteEnum = pgEnum('type_compte', ['particulier', 'pro']);

export const users = pgTable(
  'users',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    email: text().notNull(),
    passwordHash: text().notNull(),
    emailVerifiedAt: timestamp({ withTimezone: true }),
    nom: text().notNull(),
    prenom: text().notNull(),
    typeCompte: typeCompteEnum().notNull(),
    telephone: text(),
    preferences: jsonb().notNull().default({}),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
    lastLoginAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    uniqueIndex('idx_users_email').on(table.email),
    index('idx_users_deleted_at')
      .on(table.deletedAt)
      .where(sql`${table.deletedAt} IS NOT NULL`),
  ],
);

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
