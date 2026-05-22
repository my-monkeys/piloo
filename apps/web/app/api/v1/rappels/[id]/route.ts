// GET / PATCH / DELETE /api/v1/rappels/{id} (#98).
// Le rôle est résolu via l'officine_id du rappel — comme pour les boîtes.
import { UpdateRappelInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole, type Role } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { findRappelById, softDeleteRappel, updateRappel } from '@/lib/rappels/repo';
import { serializeRappel } from '@/lib/rappels/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ id: z.uuid() });

interface RouteContext {
  params: Promise<{ id: string }>;
}

async function parseParams(context: RouteContext): Promise<{ id: string } | Response> {
  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);
  return parsed.data;
}

interface ResolvedRappel {
  rappelId: string;
  officineId: string;
}

async function resolveRappel(
  request: Request,
  context: RouteContext,
  allowedRoles: readonly Role[],
): Promise<ResolvedRappel | Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  const db = getDb();
  const rappel = await findRappelById(db, params.id);
  if (!rappel) {
    return apiErrorResponse('not_found', 'Rappel introuvable.');
  }

  const partage = await requireRole(auth.user.id, rappel.officineId, allowedRoles, { db });
  if (partage instanceof Response) return partage;

  return { rappelId: rappel.id, officineId: rappel.officineId };
}

export async function GET(request: Request, context: RouteContext): Promise<Response> {
  const ctx = await resolveRappel(request, context, ['owner', 'editor', 'viewer']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const rappel = await findRappelById(db, ctx.rappelId);
  if (!rappel) return apiErrorResponse('not_found', 'Rappel introuvable.');
  return Response.json(serializeRappel(rappel), { status: 200 });
}

export async function PATCH(request: Request, context: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.clone().json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = UpdateRappelInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const ctx = await resolveRappel(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const updated = await updateRappel(db, ctx.rappelId, {
    ...(parsed.data.nom_texte !== undefined && { nomTexte: parsed.data.nom_texte }),
    ...(parsed.data.unite !== undefined && { unite: parsed.data.unite }),
    ...(parsed.data.quantite_matin !== undefined && { quantiteMatin: parsed.data.quantite_matin }),
    ...(parsed.data.quantite_midi !== undefined && { quantiteMidi: parsed.data.quantite_midi }),
    ...(parsed.data.quantite_soir !== undefined && { quantiteSoir: parsed.data.quantite_soir }),
    ...(parsed.data.quantite_coucher !== undefined && {
      quantiteCoucher: parsed.data.quantite_coucher,
    }),
    ...(parsed.data.date_debut !== undefined && { dateDebut: parsed.data.date_debut }),
    ...(parsed.data.date_fin !== undefined && { dateFin: parsed.data.date_fin }),
    ...(parsed.data.actif !== undefined && { actif: parsed.data.actif }),
    ...(parsed.data.notes !== undefined && { notes: parsed.data.notes }),
  });
  if (!updated) return apiErrorResponse('not_found', 'Rappel introuvable.');
  return Response.json(serializeRappel(updated), { status: 200 });
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const ctx = await resolveRappel(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const ok = await softDeleteRappel(db, ctx.rappelId);
  if (!ok) return apiErrorResponse('not_found', 'Rappel introuvable.');
  return new Response(null, { status: 204 });
}
