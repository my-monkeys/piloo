// packages/db-schema/src/schema/users.ts
// Source : docs/data-model.md §"users". Compte de connexion + profil minimal.
// Adapté pour Better Auth (ADR 0004) : `name`, `emailVerified`, `image` sont
// requis par le contrat Better Auth ; le mot de passe vit dans la table
// `account` (cf. schema/auth.ts), pas ici. `nom`/`prenom`/`typeCompte`/
// `telephone`/`preferences` sont injectés au signup via additionalFields.
import { sql } from 'drizzle-orm';
import {
  boolean,
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
    name: text().notNull(),
    emailVerified: boolean().notNull().default(false),
    image: text(),
    nom: text().notNull(),
    prenom: text().notNull(),
    typeCompte: typeCompteEnum().notNull(),
    telephone: text(),
    preferences: jsonb().notNull().default({}),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => new Date()),
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
