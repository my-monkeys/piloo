// GET /api/v1/officines (liste accessible) + POST /api/v1/officines (#70).
import { CreateOfficineInputSchema } from '@piloo/api-contract';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { createOfficineWithOwner, listAccessibleOfficines } from '@/lib/officines/repo';
import { serializeOfficine } from '@/lib/officines/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const db = getDb();
  const items = await listAccessibleOfficines(db, auth.user.id);

  return Response.json({ items: items.map((o) => serializeOfficine(o, o.role)) }, { status: 200 });
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

  const parsed = CreateOfficineInputSchema.safeParse(body);
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }

  const db = getDb();
  const officine = await createOfficineWithOwner(db, {
    nom: parsed.data.nom,
    type: parsed.data.type,
    dateNaissance: parsed.data.date_naissance ?? null,
    notes: parsed.data.notes ?? null,
    proprietaireUserId: auth.user.id,
  });

  return Response.json(serializeOfficine(officine, 'owner'), { status: 201 });
}
