// PATCH /api/v1/rappels/{id} : update partiel (toggle actif, heure, label).
// DELETE /api/v1/rappels/{id} : soft-delete. (#327)
import { UpdateRappelInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import {
  getRappelForUser,
  softDeleteRappelForUser,
  updateRappelForUser,
  type UpdateRappelPatch,
} from '@/lib/rappels/repo';
import { serializeRappel } from '@/lib/rappels/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ id: z.uuid() });

interface RouteContext {
  params: Promise<{ id: string }>;
}

export async function PATCH(request: Request, context: RouteContext): Promise<Response> {
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
  const parsed = UpdateRappelInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const patch: UpdateRappelPatch = {};
  if (parsed.data.label !== undefined) patch.label = parsed.data.label;
  if (parsed.data.heure !== undefined) patch.heure = normalizeHeure(parsed.data.heure);
  if (parsed.data.actif !== undefined) patch.actif = parsed.data.actif;
  if (parsed.data.boite_id !== undefined) patch.boiteId = parsed.data.boite_id;
  if (parsed.data.notes !== undefined) patch.notes = parsed.data.notes;

  const updated = await updateRappelForUser(getDb(), {
    userId: auth.user.id,
    rappelId: parsedParams.data.id,
    patch,
  });
  if (!updated) return apiErrorResponse('not_found', 'Rappel inconnu.');
  return Response.json(serializeRappel(updated), { status: 200 });
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const rawParams = await context.params;
  const parsedParams = ParamsSchema.safeParse(rawParams);
  if (!parsedParams.success) return zodErrorResponse(parsedParams.error);

  // On vérifie d'abord l'existence pour distinguer "déjà supprimé" (404)
  // d'un succès. softDeleteRappelForUser renvoie déjà false dans ce cas,
  // donc un check unique suffit.
  const existed = await getRappelForUser(getDb(), {
    userId: auth.user.id,
    rappelId: parsedParams.data.id,
  });
  if (!existed) return apiErrorResponse('not_found', 'Rappel inconnu.');

  await softDeleteRappelForUser(getDb(), {
    userId: auth.user.id,
    rappelId: parsedParams.data.id,
  });
  return new Response(null, { status: 204 });
}

function normalizeHeure(input: string): string {
  return input.length === 5 ? `${input}:00` : input;
}
