// packages/db-schema/src/schema/auth.ts
// Tables gérées par Better Auth (ADR 0004). Schéma minimal correspondant
// au contrat de l'adapter Drizzle :
// - `sessions` : sessions actives (cookie web ou bearer token mobile)
// - `accounts` : credentials d'authentification (email/password local + à
//   terme providers OAuth Apple/Google)
// - `verifications` : tokens de vérification (magic link, reset password —
//   ouvert par les tickets #62/#63)
// IDs en uuid pour rester cohérent avec le reste du schéma (cf. règle
// "IDs UUID v4" du CLAUDE.md packages/db-schema). On configure
// `advanced.database.generateId` côté apps/web pour que Better Auth
// produise des UUID au lieu des nanoid par défaut.
import { index, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.ts';

export const sessions = pgTable(
  'sessions',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    token: text().notNull(),
    expiresAt: timestamp({ withTimezone: true }).notNull(),
    ipAddress: text(),
    userAgent: text(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => new Date()),
  },
  (table) => [
    uniqueIndex('idx_sessions_token').on(table.token),
    index('idx_sessions_user_id').on(table.userId),
  ],
);

export const accounts = pgTable(
  'accounts',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    accountId: text().notNull(),
    providerId: text().notNull(),
    accessToken: text(),
    refreshToken: text(),
    idToken: text(),
    accessTokenExpiresAt: timestamp({ withTimezone: true }),
    refreshTokenExpiresAt: timestamp({ withTimezone: true }),
    scope: text(),
    password: text(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => new Date()),
  },
  (table) => [
    index('idx_accounts_user_id').on(table.userId),
    uniqueIndex('idx_accounts_provider_account').on(table.providerId, table.accountId),
  ],
);

export const verifications = pgTable(
  'verifications',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    identifier: text().notNull(),
    value: text().notNull(),
    expiresAt: timestamp({ withTimezone: true }).notNull(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true })
      .notNull()
      .defaultNow()
      .$onUpdate(() => new Date()),
  },
  (table) => [index('idx_verifications_identifier').on(table.identifier)],
);

export type Session = typeof sessions.$inferSelect;
export type Account = typeof accounts.$inferSelect;
export type Verification = typeof verifications.$inferSelect;
