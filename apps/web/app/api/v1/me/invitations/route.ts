// GET /api/v1/me/invitations (#129).
//
// Liste les invitations en attente adressées à l'utilisateur courant.
// "Adressées" = email de l'invitation matche l'email de l'user authentifié.
// Si l'invitation n'a pas d'email (lien partagé non personnalisé), elle
// n'est PAS retournée ici — l'utilisateur doit l'accepter via le lien
// dédié (workflow existant /invitations/{token}).
//
// Statut pending = `acceptedAt IS NULL AND deletedAt IS NULL AND expiresAt > now()`.
import { invitations, officines, users, type Db } from '@piloo/db-schema';
import { and, eq, gt, isNull } from 'drizzle-orm';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import type { PendingInvitationsList } from '@piloo/api-contract';

export const dynamic = 'force-dynamic';

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  try {
    const items = await fetchPendingInvitationsFor(getDb(), auth.user.email);
    const payload: PendingInvitationsList = { items };
    return Response.json(payload);
  } catch {
    return apiErrorResponse('internal_error', 'Impossible de charger les invitations.');
  }
}

async function fetchPendingInvitationsFor(db: Db, email: string) {
  const now = new Date();
  const rows = await db
    .select({
      token: invitations.id,
      officineId: invitations.officineId,
      officineNom: officines.nom,
      role: invitations.role,
      invitedByName: users.name,
      expiresAt: invitations.expiresAt,
    })
    .from(invitations)
    .innerJoin(officines, eq(invitations.officineId, officines.id))
    .innerJoin(users, eq(invitations.invitedByUserId, users.id))
    .where(
      and(
        eq(invitations.email, email),
        isNull(invitations.acceptedAt),
        isNull(invitations.deletedAt),
        gt(invitations.expiresAt, now),
      ),
    );

  return rows.map((r) => ({
    token: r.token,
    officine_id: r.officineId,
    officine_nom: r.officineNom,
    role: r.role,
    invited_by_name: r.invitedByName,
    expires_at: r.expiresAt.toISOString(),
  }));
}
