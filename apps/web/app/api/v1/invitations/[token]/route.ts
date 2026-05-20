// GET /api/v1/invitations/{token} — preview public (#125).
//
// Public car appelé depuis le lien partageable AVANT que l'invité soit
// authentifié. Retourne juste le nom de l'officine + rôle + inviteur +
// statut, pas les IDs internes ni l'email (PII protégée).
import { z } from 'zod';

import { getDb } from '@/lib/db';
import { findInvitationByToken } from '@/lib/invitations/repo';
import { serializePreview } from '@/lib/invitations/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ token: z.uuid() });

interface RouteContext {
  params: Promise<{ token: string }>;
}

export async function GET(_request: Request, context: RouteContext): Promise<Response> {
  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const row = await findInvitationByToken(getDb(), parsed.data.token);
  if (!row) return apiErrorResponse('not_found', 'Invitation inconnue.');

  return Response.json(serializePreview(row.invitation, row.officineNom, row.invitedByName), {
    status: 200,
  });
}
