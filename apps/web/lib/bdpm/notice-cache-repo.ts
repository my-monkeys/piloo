// Repo bdpm_notices_cache : encapsule les accès DB au cache de notices RCP.
//
// La logique de fraîcheur (7 jours) vit dans la route plutôt qu'ici — on
// reste un simple CRUD pour faciliter les tests.
import { bdpmNoticesCache, type BdpmNoticeCache, type CachedNoticeSection } from '@piloo/db-schema';
import { and, eq, lt, sql } from 'drizzle-orm';

import type { Db } from '@piloo/db-schema';

type Database = Db;

export const STALE_AFTER_MS = 7 * 24 * 60 * 60 * 1000;

export async function getNoticeCache(db: Database, cis: string): Promise<BdpmNoticeCache | null> {
  const rows = await db
    .select()
    .from(bdpmNoticesCache)
    .where(eq(bdpmNoticesCache.cis, cis))
    .limit(1);
  return rows[0] ?? null;
}

export async function upsertNoticeCache(
  db: Database,
  input: {
    cis: string;
    sourceUrl: string;
    sections: CachedNoticeSection[];
  },
): Promise<void> {
  await db
    .insert(bdpmNoticesCache)
    .values({
      cis: input.cis,
      sourceUrl: input.sourceUrl,
      sections: input.sections,
      refreshing: false,
    })
    .onConflictDoUpdate({
      target: bdpmNoticesCache.cis,
      set: {
        sourceUrl: input.sourceUrl,
        sections: input.sections,
        scrapedAt: sql`now()`,
        refreshing: false,
      },
    });
}

/// Tente de poser un verrou "refreshing" sur une entrée stale, en une seule
/// requête atomique. Retourne true si le caller a obtenu le verrou et doit
/// faire le scrape ; false sinon (un autre process l'a déjà pris ou l'entrée
/// est fresh).
///
/// La condition `scraped_at < now - 7j` évite qu'on prenne un verrou sur
/// une entrée encore fraîche, ce qui pourrait arriver si deux requêtes
/// arrivent simultanément après que l'une vienne de refresh.
export async function tryAcquireRefreshLock(db: Database, cis: string): Promise<boolean> {
  const staleCutoff = new Date(Date.now() - STALE_AFTER_MS);
  const updated = await db
    .update(bdpmNoticesCache)
    .set({ refreshing: true })
    .where(
      and(
        eq(bdpmNoticesCache.cis, cis),
        eq(bdpmNoticesCache.refreshing, false),
        lt(bdpmNoticesCache.scrapedAt, staleCutoff),
      ),
    )
    .returning({ cis: bdpmNoticesCache.cis });
  return updated.length > 0;
}

export async function clearRefreshLock(db: Database, cis: string): Promise<void> {
  await db.update(bdpmNoticesCache).set({ refreshing: false }).where(eq(bdpmNoticesCache.cis, cis));
}

export function isStale(cache: BdpmNoticeCache): boolean {
  return Date.now() - cache.scrapedAt.getTime() > STALE_AFTER_MS;
}
