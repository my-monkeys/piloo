// GET /api/v1/prises?officine_id=...&date=YYYY-MM-DD (#114).
// Variante de /v1/prises/today qui prend une date explicite — utilisé
// par le navigateur de calendrier du mobile.
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { listPrisesForDay } from '@/lib/prises/repo';
import { dayBoundsUtc, serializePriseTimelineItem } from '@/lib/prises/serialize';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const QuerySchema = z.object({
  officine_id: z.uuid(),
  date: z.iso.date(),
});

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const url = new URL(request.url);
  const parsed = QuerySchema.safeParse({
    officine_id: url.searchParams.get('officine_id') ?? undefined,
    date: url.searchParams.get('date') ?? undefined,
  });
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }

  const db = getDb();
  const partage = await requireRole(
    auth.user.id,
    parsed.data.officine_id,
    ['owner', 'editor', 'viewer'],
    { db },
  );
  if (partage instanceof Response) return partage;

  const { dayStart, dayEnd } = dayBoundsUtc(parsed.data.date);
  const rows = await listPrisesForDay(db, {
    officineId: parsed.data.officine_id,
    dayStart,
    dayEnd,
  });

  return Response.json(
    {
      date: parsed.data.date,
      items: rows.map((r) => serializePriseTimelineItem(r.prise, r.prescription)),
    },
    { status: 200 },
  );
}
