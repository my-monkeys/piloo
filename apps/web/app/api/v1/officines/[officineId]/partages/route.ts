// GET /api/v1/officines/{officineId}/partages (#339).
//
// Liste les membres actifs + les invitations en attente. Lecture
// autorisée aux 3 rôles (viewer compris) — un membre peut voir
// qui d'autre fait partie de l'officine.
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { listMembers, listPendingInvitations } from '@/lib/partages/repo';
import { serializeMember, serializePendingInvitation } from '@/lib/partages/serialize';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ officineId: z.uuid() });

interface RouteContext {
  params: Promise<{ officineId: string }>;
}

export async function GET(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const partage = await requireRole(
    auth.user.id,
    parsed.data.officineId,
    ['owner', 'editor', 'viewer'],
    { db },
  );
  if (partage instanceof Response) return partage;

  const [members, pending] = await Promise.all([
    listMembers(db, parsed.data.officineId),
    listPendingInvitations(db, parsed.data.officineId),
  ]);

  return Response.json(
    {
      members: members.map(serializeMember),
      pending_invitations: pending.map(serializePendingInvitation),
    },
    { status: 200 },
  );
}
