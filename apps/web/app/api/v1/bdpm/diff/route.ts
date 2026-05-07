// GET /api/v1/bdpm/diff?from=YYYY-MM-DD (#76).
//
// Public — voir /version pour le rationale. Retourne les médicaments
// dont `version_bdpm > from`. Limite : pas de tracking des CIS retirés
// (cf. schema.bdpm — table sans soft-delete).
import { BdpmDiffQuerySchema, type BdpmDiffResponse } from '@piloo/api-contract';

import { getBdpmDiffSince, getBdpmStats } from '@/lib/bdpm/repo';
import { serializeBdpmMedicament } from '@/lib/bdpm/serialize';
import { getDb } from '@/lib/db';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const params = Object.fromEntries(url.searchParams.entries());
  const parsed = BdpmDiffQuerySchema.safeParse(params);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const [stats, items] = await Promise.all([
    getBdpmStats(db),
    getBdpmDiffSince(db, parsed.data.from),
  ]);

  const body: BdpmDiffResponse = {
    from: parsed.data.from,
    current: stats.version,
    items: items.map(serializeBdpmMedicament),
  };
  return Response.json(body, { status: 200 });
}
