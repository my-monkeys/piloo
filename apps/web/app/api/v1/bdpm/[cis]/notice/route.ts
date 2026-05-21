// GET /api/v1/bdpm/{cis}/notice — scrape la notice ANSM à la demande.
//
// Public (BDPM = open data). Cache HTTP côté CDN/Vercel pour éviter de
// re-scraper la même page à chaque tap utilisateur — le RCP change
// rarement (modifs AMM tous les 1-2 ans en moyenne).
//
// Cache : `s-maxage=604800` (7 jours) côté edge + `stale-while-revalidate`
// pour servir le cache pendant qu'on refresh en arrière-plan.
import { z } from 'zod';

import type { BdpmNoticeResponse } from '@piloo/api-contract';

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

  try {
    const notice = await scrapeNoticeFromAnsm(parsed.data.cis);
    const body: BdpmNoticeResponse = {
      cis: notice.cis,
      source_url: notice.sourceUrl,
      scraped_at: notice.scrapedAt,
      sections: notice.sections,
    };
    return Response.json(body, {
      headers: {
        // 7 jours edge cache + 1 jour SWR.
        'Cache-Control': 'public, s-maxage=604800, stale-while-revalidate=86400',
      },
    });
  } catch (e) {
    log.error('bdpm.notice.scrape_failed', {
      cis: parsed.data.cis,
      message: e instanceof Error ? e.message : 'unknown',
    });
    return apiErrorResponse('internal_error', 'Impossible de récupérer la notice ANSM.');
  }
}
