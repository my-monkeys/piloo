// GET /api/v1/bdpm/version (#76).
//
// Public — pas d'auth requise. BDPM est une donnée ouverte, et le mobile
// appelle cet endpoint avant même d'avoir un user signé pour décider s'il
// doit télécharger la base offline.
import type { BdpmVersionResponse } from '@piloo/api-contract';

import { getBdpmStats } from '@/lib/bdpm/repo';
import { getDb } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(): Promise<Response> {
  const db = getDb();
  const stats = await getBdpmStats(db);
  const body: BdpmVersionResponse = {
    version: stats.version,
    total_cis: stats.totalCis,
  };
  return Response.json(body, { status: 200 });
}
