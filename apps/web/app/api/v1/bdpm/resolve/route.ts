// GET /api/v1/bdpm/resolve?cips=a,b,c — résolution batch CIP13 → médicament.
//
// Public (BDPM = open data). Sert au front web à afficher les NOMS des
// médicaments sur une liste d'inventaire (#370). Le type Boite ne stocke que
// le cip13 ; ce endpoint fait le pont vers la dénomination BDPM.
import { BdpmResolveQuerySchema, type BdpmResolveResponse } from '@piloo/api-contract';

import { resolveBdpmByCips } from '@/lib/bdpm/repo';
import { serializeBdpmMedicament } from '@/lib/bdpm/serialize';
import { getDb } from '@/lib/db';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const parsed = BdpmResolveQuerySchema.safeParse(Object.fromEntries(url.searchParams.entries()));
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const cips = parsed.data.cips
    .split(',')
    .map((c) => c.trim())
    .filter((c) => c.length > 0);

  const db = getDb();
  const items = await resolveBdpmByCips(db, cips);
  const body: BdpmResolveResponse = { items: items.map(serializeBdpmMedicament) };
  return Response.json(body, { status: 200 });
}
