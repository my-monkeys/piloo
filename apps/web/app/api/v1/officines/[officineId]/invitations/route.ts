// POST /api/v1/officines/{officineId}/invitations (#123).
//
// Crée une invitation à rejoindre l'officine avec un rôle donné.
// Owner uniquement — un editor ne peut pas inviter de nouveaux
// membres (cf. matrice RBAC docs/data-model.md §Partages).
import { CreateInvitationInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { createInvitation } from '@/lib/invitations/repo';
import { serializeInvitation } from '@/lib/invitations/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ officineId: z.uuid() });

interface RouteContext {
  params: Promise<{ officineId: string }>;
}

export async function POST(request: Request, context: RouteContext): Promise<Response> {
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
  const parsedBody = CreateInvitationInputSchema.safeParse(body);
  if (!parsedBody.success) return zodErrorResponse(parsedBody.error);

  const db = getDb();
  const partage = await requireRole(auth.user.id, parsedParams.data.officineId, ['owner'], { db });
  if (partage instanceof Response) return partage;

  const invitation = await createInvitation(db, {
    officineId: parsedParams.data.officineId,
    invitedByUserId: auth.user.id,
    role: parsedBody.data.role,
    email: parsedBody.data.email ?? null,
    ttlHours: parsedBody.data.ttlHours ?? 72,
  });

  return Response.json(serializeInvitation(invitation), { status: 201 });
}
