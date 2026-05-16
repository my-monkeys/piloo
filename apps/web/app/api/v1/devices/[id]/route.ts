// DELETE /api/v1/devices/:id : soft-delete d'un device du user courant
// (typiquement appelé à la déconnexion). (#124)
import { z } from 'zod';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { softDeleteDevice } from '@/lib/devices/repo';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ id: z.uuid() });

interface RouteContext {
  params: Promise<{ id: string }>;
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }

  const deleted = await softDeleteDevice(getDb(), {
    userId: auth.user.id,
    deviceId: parsed.data.id,
  });
  if (!deleted) {
    return apiErrorResponse('not_found', 'Device introuvable.');
  }
  return new Response(null, { status: 204 });
}
