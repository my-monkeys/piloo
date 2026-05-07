// POST /api/v1/alertes/:id/read (#140).
import { z } from 'zod';

import { requireAuth } from '@/lib/auth/guards';
import { markAlerteRead } from '@/lib/alertes/repo';
import { getDb } from '@/lib/db';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ id: z.uuid() });

interface RouteContext {
  params: Promise<{ id: string }>;
}

export async function POST(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const ok = await markAlerteRead(db, auth.user.id, parsed.data.id);
  if (!ok) {
    return apiErrorResponse('not_found', 'Alerte introuvable ou non destinée à cet utilisateur.');
  }
  return new Response(null, { status: 204 });
}
