// GET /api/v1/bdpm/search?q=... — recherche manuelle pour création boîte web.
//
// Public (BDPM = open data). Le rate-limit éventuel se fait au niveau infra
// (Caddy / Vercel) — pas de besoin métier de bloquer ici.
import { BdpmSearchQuerySchema, type BdpmSearchResponse } from '@piloo/api-contract';

import { searchBdpm } from '@/lib/bdpm/repo';
import { serializeBdpmMedicament } from '@/lib/bdpm/serialize';
import { getDb } from '@/lib/db';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const parsed = BdpmSearchQuerySchema.safeParse(Object.fromEntries(url.searchParams.entries()));
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const items = await searchBdpm(db, parsed.data.q);
  const body: BdpmSearchResponse = { items: items.map(serializeBdpmMedicament) };
  return Response.json(body, { status: 200 });
}
