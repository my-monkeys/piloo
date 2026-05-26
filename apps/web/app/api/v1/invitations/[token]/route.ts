// GET /api/v1/invitations/{token} — preview public (#125).
// DELETE /api/v1/invitations/{token} — soft-delete (revoke) a pending invitation.
//
// GET is public (called from the shareable link BEFORE the invitee is
// authenticated). Returns only officine name + role + inviter + status,
// not internal IDs or email (PII protected).
//
// DELETE requires auth + owner role on the invitation's officine.
// Only pending invitations (not yet accepted, not yet deleted) can be
// revoked. Returns 204 on success, 404 if not found or not pending.
import { invitations } from '@piloo/db-schema';
import { and, eq, isNull } from 'drizzle-orm';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
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

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();

  // Look up the invitation to get its officineId for the role check.
  const row = await findInvitationByToken(db, parsed.data.token);
  if (!row) return apiErrorResponse('not_found', 'Invitation inconnue.');

  // Only the officine owner can revoke invitations.
  const partage = await requireRole(auth.user.id, row.invitation.officineId, ['owner'], { db });
  if (partage instanceof Response) return partage;

  // Soft-delete only if the invitation is still pending (not accepted, not already deleted).
  const now = new Date();
  const [updated] = await db
    .update(invitations)
    .set({ deletedAt: now, updatedAt: now })
    .where(
      and(
        eq(invitations.id, parsed.data.token),
        isNull(invitations.acceptedAt),
        isNull(invitations.deletedAt),
      ),
    )
    .returning({ id: invitations.id });

  if (!updated) {
    return apiErrorResponse('not_found', 'Invitation déjà acceptée ou révoquée.');
  }

  return new Response(null, { status: 204 });
}
