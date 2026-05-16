// packages/db-schema/src/schema/devices.ts
// Enregistrement des devices mobiles d'un user pour FCM (#124).
//
// Un user peut avoir N devices (multi-device support). Le couple
// (user_id, token) est unique — réenregistrer le même token pour le
// même user → update du `last_seen_at` (idempotent côté repo).
//
// Soft-delete : un token marqué invalide par FCM est `deleted_at` non
// nul. On garde une trace plutôt qu'un DELETE dur, pour pouvoir
// diagnostiquer "pourquoi cet user ne reçoit plus de push".
import { index, pgEnum, pgTable, text, timestamp, unique, uuid } from 'drizzle-orm/pg-core';

import { users } from './users.ts';

export const devicePlatformEnum = pgEnum('device_platform', ['ios', 'android', 'web']);

export const devices = pgTable(
  'devices',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    token: text().notNull(),
    platform: devicePlatformEnum().notNull(),
    // Optionnel — utile pour les diagnostics ("ce user reçoit-il bien
    // les v2 de l'app ?"). Pas un blocker.
    appVersion: text(),
    createdAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp({ withTimezone: true }),
  },
  (table) => [
    index('idx_devices_user').on(table.userId),
    unique('uq_devices_user_token').on(table.userId, table.token),
  ],
);

export type Device = typeof devices.$inferSelect;
export type NewDevice = typeof devices.$inferInsert;
