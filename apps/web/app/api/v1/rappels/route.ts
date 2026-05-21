// GET /api/v1/rappels : liste les rappels du user courant.
// POST /api/v1/rappels : crée un nouveau rappel. (#327)
import { CreateRappelInputSchema } from '@piloo/api-contract';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { createRappel, listRappelsForUser } from '@/lib/rappels/repo';
import { serializeRappel } from '@/lib/rappels/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const items = await listRappelsForUser(getDb(), auth.user.id);
  return Response.json({ items: items.map(serializeRappel) }, { status: 200 });
}

export async function POST(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = CreateRappelInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const row = await createRappel(getDb(), {
    userId: auth.user.id,
    label: parsed.data.label,
    heure: normalizeHeure(parsed.data.heure),
    officineId: parsed.data.officine_id ?? null,
    boiteId: parsed.data.boite_id ?? null,
    recurrenceType: parsed.data.recurrence_type,
    notes: parsed.data.notes ?? null,
  });
  return Response.json(serializeRappel(row), { status: 201 });
}

/// Postgres `time` stocke en HH:MM:SS. Le client envoie souvent HH:MM
/// (TimePicker iOS/Android) → on append :00 pour éviter une rejet DB.
function normalizeHeure(input: string): string {
  return input.length === 5 ? `${input}:00` : input;
}
