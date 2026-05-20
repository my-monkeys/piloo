// POST /api/v1/invitations/{token}/accept — accept invitation (#125).
//
// Requiert l'auth (l'utilisateur qui accepte est l'utilisateur courant).
// Insère/réactive un `partages` row + marque l'invitation acceptée.
// 409 si l'invitation est déjà acceptée / révoquée / expirée.
import { z } from 'zod';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { acceptInvitation, findInvitationByToken, isPending } from '@/lib/invitations/repo';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ token: z.uuid() });

interface RouteContext {
  params: Promise<{ token: string }>;
}

export async function POST(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const row = await findInvitationByToken(db, parsed.data.token);
  if (!row) return apiErrorResponse('not_found', 'Invitation inconnue.');

  if (!isPending(row.invitation)) {
    return apiErrorResponse('conflict', 'Invitation déjà acceptée, révoquée ou expirée.');
  }

  const result = await acceptInvitation(db, row.invitation, auth.user.id);
  log.info('invitation.accepted', {
    invitationId: row.invitation.id,
    officineId: result.officineId,
    role: result.role,
  });
  return Response.json({ officine_id: result.officineId, role: result.role }, { status: 200 });
}
