// PATCH + DELETE /api/v1/officines/{officineId}/partages/{userId} (#339).
//
// PATCH  → change le rôle d'un membre (owner uniquement, garde-fou
//          "dernier owner" pour empêcher de se rétrograder seul).
// DELETE → soft-delete d'un membre. Owner pour révoquer un autre,
//          OU le membre lui-même pour quitter l'officine. Refuse si
//          c'est le dernier owner.
import { UpdatePartageRoleInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import {
  countActiveOwners,
  findMember,
  softDeleteMember,
  updateMemberRole,
} from '@/lib/partages/repo';
import { serializeMember } from '@/lib/partages/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({
  officineId: z.uuid(),
  userId: z.uuid(),
});

interface RouteContext {
  params: Promise<{ officineId: string; userId: string }>;
}

async function parseParams(
  context: RouteContext,
): Promise<{ officineId: string; userId: string } | Response> {
  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);
  return parsed.data;
}

export async function PATCH(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsedBody = UpdatePartageRoleInputSchema.safeParse(body);
  if (!parsedBody.success) return zodErrorResponse(parsedBody.error);

  const db = getDb();
  // Seul un owner peut changer un rôle (y compris promouvoir un autre).
  const guard = await requireRole(auth.user.id, params.officineId, ['owner'], { db });
  if (guard instanceof Response) return guard;

  const existing = await findMember(db, params.officineId, params.userId);
  if (!existing) return apiErrorResponse('not_found', 'Membre introuvable.');

  // Garde-fou : si on retire le rôle owner au dernier owner, refuse.
  // (Y compris si l'owner se rétrograde lui-même alors qu'il est seul.)
  if (existing.partage.role === 'owner' && parsedBody.data.role !== 'owner') {
    const owners = await countActiveOwners(db, params.officineId);
    if (owners <= 1) {
      return apiErrorResponse(
        'conflict',
        'Au moins un owner actif est requis. Promouvez un autre membre avant de vous rétrograder.',
      );
    }
  }

  const updated = await updateMemberRole(
    db,
    params.officineId,
    params.userId,
    parsedBody.data.role,
  );
  if (!updated) return apiErrorResponse('not_found', 'Membre introuvable.');

  return Response.json(serializeMember(updated), { status: 200 });
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  const db = getDb();
  const isSelf = auth.user.id === params.userId;
  // L'user peut se retirer lui-même (n'importe quel rôle) ; sinon
  // il faut être owner pour révoquer quelqu'un d'autre.
  const guard = await requireRole(
    auth.user.id,
    params.officineId,
    isSelf ? ['owner', 'editor', 'viewer'] : ['owner'],
    { db },
  );
  if (guard instanceof Response) return guard;

  const existing = await findMember(db, params.officineId, params.userId);
  if (!existing) return apiErrorResponse('not_found', 'Membre introuvable.');

  // Garde-fou : on ne supprime jamais le dernier owner (ni par
  // self-leave, ni par révocation).
  if (existing.partage.role === 'owner') {
    const owners = await countActiveOwners(db, params.officineId);
    if (owners <= 1) {
      return apiErrorResponse(
        'conflict',
        "Dernier owner de l'officine — promouvez d'abord un autre membre.",
      );
    }
  }

  const ok = await softDeleteMember(db, params.officineId, params.userId);
  if (!ok) return apiErrorResponse('not_found', 'Membre introuvable.');

  return new Response(null, { status: 204 });
}
