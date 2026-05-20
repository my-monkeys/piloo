// GET /api/v1/admin/summaries — liste paginée des résumés IA pour
// validation manuelle (#166).
//
// Query :
//   q      : recherche dans denomination (ILIKE, optionnel)
//   only   : 'missing' | 'set' (par défaut tout)
//   limit  : 1..200 (défaut 50)
//   offset : pagination
import { medicamentsBdpm } from '@piloo/db-schema';
import { and, asc, ilike, isNotNull, isNull, sql } from 'drizzle-orm';
import { z } from 'zod';

import { requireAdmin } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const QuerySchema = z.object({
  q: z.string().optional(),
  only: z.enum(['missing', 'set']).optional(),
  limit: z.coerce.number().int().min(1).max(200).optional().default(50),
  offset: z.coerce.number().int().min(0).optional().default(0),
});

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) return auth;

  const url = new URL(request.url);
  const parsed = QuerySchema.safeParse({
    q: url.searchParams.get('q') ?? undefined,
    only: url.searchParams.get('only') ?? undefined,
    limit: url.searchParams.get('limit') ?? undefined,
    offset: url.searchParams.get('offset') ?? undefined,
  });
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const whereParts = [];
  if (parsed.data.q) {
    whereParts.push(ilike(medicamentsBdpm.denomination, `%${parsed.data.q}%`));
  }
  if (parsed.data.only === 'missing') {
    whereParts.push(isNull(medicamentsBdpm.aiSummary));
  } else if (parsed.data.only === 'set') {
    whereParts.push(isNotNull(medicamentsBdpm.aiSummary));
  }
  const where = whereParts.length > 0 ? and(...whereParts) : undefined;

  const items = await db
    .select({
      cip13: medicamentsBdpm.cip13,
      denomination: medicamentsBdpm.denomination,
      dosage: medicamentsBdpm.dosage,
      forme: medicamentsBdpm.forme,
      titulaire: medicamentsBdpm.titulaire,
      aiSummary: medicamentsBdpm.aiSummary,
      aiSummaryVersion: medicamentsBdpm.aiSummaryVersion,
    })
    .from(medicamentsBdpm)
    .where(where)
    .orderBy(asc(medicamentsBdpm.denomination))
    .limit(parsed.data.limit)
    .offset(parsed.data.offset);

  const [counts] = await db
    .select({
      total: sql<number>`count(*)::int`,
      withSummary: sql<number>`count(*) filter (where ${medicamentsBdpm.aiSummary} is not null)::int`,
    })
    .from(medicamentsBdpm);

  return Response.json({
    items,
    total: counts?.total ?? 0,
    with_summary: counts?.withSummary ?? 0,
  });
}
