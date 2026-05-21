// GET /api/v1/bdpm/{cis}/notice — sert la notice ANSM depuis le cache DB.
//
// Stratégie :
//   1. Cache hit fresh (< 7j)   → renvoie depuis DB (~20ms, pas de scrape).
//   2. Cache hit stale (>= 7j)  → renvoie le cache stale immédiatement +
//      déclenche un refresh background (waitUntil). L'user n'attend pas.
//   3. Cache miss               → scrape live, insert, renvoie (~500ms-2s).
//
// Public (BDPM = open data). Plus de Cache-Control HTTP edge : la DB est
// désormais la source de vérité, et on veut que les refresh background
// passent immédiatement (sans cache CDN qui mémorise une réponse vide).
import { z } from 'zod';
import { waitUntil } from '@vercel/functions';

import type { BdpmNoticeResponse } from '@piloo/api-contract';

import { getDb } from '@/lib/db';
import {
  clearRefreshLock,
  getNoticeCache,
  isStale,
  tryAcquireRefreshLock,
  upsertNoticeCache,
} from '@/lib/bdpm/notice-cache-repo';
import { scrapeNoticeFromAnsm } from '@/lib/bdpm/notice-scraper';
import { log } from '@/lib/server/logger';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ cis: z.string().min(1).max(32) });

interface RouteContext {
  params: Promise<{ cis: string }>;
}

export async function GET(_request: Request, context: RouteContext): Promise<Response> {
  const rawParams = await context.params;
  const parsed = ParamsSchema.safeParse(rawParams);
  if (!parsed.success) return zodErrorResponse(parsed.error);
  const cis = parsed.data.cis;

  const db = getDb();

  try {
    const cached = await getNoticeCache(db, cis);
    if (cached) {
      if (isStale(cached)) {
        // Tente de prendre le verrou refresh. Si on l'a, on enqueue le
        // re-scrape. Sinon, un autre worker s'en occupe déjà.
        const gotLock = await tryAcquireRefreshLock(db, cis);
        if (gotLock) {
          waitUntil(refreshInBackground(cis));
        }
      }
      return Response.json(
        toResponse(cached.cis, cached.sourceUrl, cached.scrapedAt, cached.sections),
      );
    }

    // Cache miss : scrape live + insert.
    const notice = await scrapeNoticeFromAnsm(cis);
    await upsertNoticeCache(db, {
      cis: notice.cis,
      sourceUrl: notice.sourceUrl,
      sections: notice.sections,
    });
    return Response.json(
      toResponse(notice.cis, notice.sourceUrl, new Date(notice.scrapedAt), notice.sections),
    );
  } catch (e) {
    log.error('bdpm.notice.fetch_failed', {
      cis,
      message: e instanceof Error ? e.message : 'unknown',
    });
    return apiErrorResponse('internal_error', 'Impossible de récupérer la notice ANSM.');
  }
}

function toResponse(
  cis: string,
  sourceUrl: string,
  scrapedAt: Date,
  sections: { number: string; title: string; text: string }[],
): BdpmNoticeResponse {
  return {
    cis,
    source_url: sourceUrl,
    scraped_at: scrapedAt.toISOString(),
    sections,
  };
}

/// Re-scrape ANSM puis upsert. Le verrou `refreshing` a déjà été posé par
/// `tryAcquireRefreshLock` avant cet appel ; upsert le remet à false (ou
/// `clearRefreshLock` en cas d'échec scrape).
async function refreshInBackground(cis: string): Promise<void> {
  const db = getDb();
  try {
    const fresh = await scrapeNoticeFromAnsm(cis);
    await upsertNoticeCache(db, {
      cis: fresh.cis,
      sourceUrl: fresh.sourceUrl,
      sections: fresh.sections,
    });
    log.info('bdpm.notice.refreshed', { cis, sections: fresh.sections.length });
  } catch (e) {
    log.warn('bdpm.notice.refresh_failed', {
      cis,
      message: e instanceof Error ? e.message : 'unknown',
    });
    // On libère le verrou pour qu'une prochaine requête puisse retenter,
    // mais on laisse le cache stale tel quel — mieux que rien.
    await clearRefreshLock(db, cis).catch(() => undefined);
  }
}
