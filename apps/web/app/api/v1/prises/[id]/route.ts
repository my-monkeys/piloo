// PATCH /api/v1/prises/{id} — validation manuelle (Prise/Sautée/Reset).
//
// La transition vers `oubliee` est explicitement bloquée par le schéma Zod
// (cf. api-contract/prises.ts) : elle est terminale et posée uniquement par
// le cron #118.
import { UpdatePriseInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { getOfficineTimezone } from '@/lib/officines/repo';
import { findPriseById, updatePrise } from '@/lib/prises/repo';
import { serializePriseTimelineItem } from '@/lib/prises/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ id: z.uuid() });

interface RouteContext {
  params: Promise<{ id: string }>;
}

export async function PATCH(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const rawParams = await context.params;
  const parsedParams = ParamsSchema.safeParse(rawParams);
  if (!parsedParams.success) return zodErrorResponse(parsedParams.error);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsedBody = UpdatePriseInputSchema.safeParse(body);
  if (!parsedBody.success) return zodErrorResponse(parsedBody.error);

  const db = getDb();
  const existing = await findPriseById(db, parsedParams.data.id);
  if (!existing) return apiErrorResponse('not_found', 'Prise introuvable.');

  const partage = await requireRole(auth.user.id, existing.prise.officineId, ['owner', 'editor'], {
    db,
  });
  if (partage instanceof Response) return partage;

  const updated = await updatePrise(db, parsedParams.data.id, {
    statut: parsedBody.data.statut,
    notes: parsedBody.data.notes,
    datetimePrevue: parsedBody.data.datetime_prevue
      ? new Date(parsedBody.data.datetime_prevue)
      : undefined,
    userId: auth.user.id,
  });
  if (!updated) return apiErrorResponse('not_found', 'Prise introuvable.');

  const timeZone = await getOfficineTimezone(db, updated.prise.officineId);
  return Response.json(
    serializePriseTimelineItem(updated.prise, updated.prescription, updated.rappel, timeZone),
    {
      status: 200,
    },
  );
}
