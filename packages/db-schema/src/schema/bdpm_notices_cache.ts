// Cache persistant des notices RCP scrapées depuis ANSM
// (cf. apps/web/lib/bdpm/notice-scraper.ts).
//
// Source de vérité côté serveur. Avantages vs cache HTTP edge :
//   - Survit aux purges Vercel.
//   - Permet de servir une réponse stale en < 50ms même si ANSM est down.
//   - Permet la pré-distribution offline côté mobile (table Drift miroir).
//
// Stratégie de fraîcheur : 7 jours. Au-delà, on sert la réponse stale ET
// on enqueue un refresh en background (Vercel `waitUntil`). L'user n'attend
// jamais le scrape ANSM (~500ms à 2s).
import { boolean, jsonb, pgTable, text, timestamp } from 'drizzle-orm/pg-core';

export interface CachedNoticeSection {
  number: string;
  title: string;
  text: string;
}

export const bdpmNoticesCache = pgTable('bdpm_notices_cache', {
  /// CIS du médicament. Pas de FK vers medicaments_bdpm car BDPM est
  /// re-importé en remplaçant les lignes — un CIS valide aujourd'hui
  /// peut disparaître au prochain import (rare, mais ça arrive sur les
  /// AMM retirées).
  cis: text().primaryKey(),
  sourceUrl: text().notNull(),
  /// Sections RCP scrapées. JSONB pour rester souple si le shape évolue
  /// (ex: ajout d'un champ `lastModifiedOnAnsm` plus tard).
  sections: jsonb().$type<CachedNoticeSection[]>().notNull(),
  scrapedAt: timestamp({ withTimezone: true }).notNull().defaultNow(),
  /// Flag anti-concurrence : si un refresh background est déjà en cours
  /// pour ce CIS, les autres requêtes n'en relancent pas un second.
  /// Reset à false à la fin du scrape (succès OU échec).
  refreshing: boolean().notNull().default(false),
});

export type BdpmNoticeCache = typeof bdpmNoticesCache.$inferSelect;
export type NewBdpmNoticeCache = typeof bdpmNoticesCache.$inferInsert;
