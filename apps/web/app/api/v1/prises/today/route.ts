// GET /api/v1/prises/today?officine_id=... (#114).
// Renvoie les prises de l'officine pour la date courante (UTC serveur),
// avec la prescription jointe inline. Sucre pour /v1/prises?date=YYYY-MM-DD.
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { getOfficineTimezone } from '@/lib/officines/repo';
import { listPrisesForDay } from '@/lib/prises/repo';
import { dayBoundsUtc, serializePriseTimelineItem, todayIso } from '@/lib/prises/serialize';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const QuerySchema = z.object({ officine_id: z.uuid() });

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const url = new URL(request.url);
  const parsed = QuerySchema.safeParse({
    officine_id: url.searchParams.get('officine_id') ?? undefined,
  });
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }

  const db = getDb();
  // Tout user avec accès à l'officine peut lire sa timeline (viewer
  // inclus — c'est de la consultation, pas de la modification).
  const partage = await requireRole(
    auth.user.id,
    parsed.data.officine_id,
    ['owner', 'editor', 'viewer'],
    { db },
  );
  if (partage instanceof Response) return partage;

  const date = todayIso();
  const { dayStart, dayEnd } = dayBoundsUtc(date);
  const rows = await listPrisesForDay(db, {
    officineId: parsed.data.officine_id,
    dayStart,
    dayEnd,
  });
  const timeZone = await getOfficineTimezone(db, parsed.data.officine_id);

  return Response.json(
    {
      date,
      items: rows.map((r) =>
        serializePriseTimelineItem(r.prise, r.prescription, r.rappel, timeZone),
      ),
    },
    { status: 200 },
  );
}
