// GET / PATCH / DELETE /api/v1/boites/:id (#86).
// La résolution du rôle passe par l'officine_id de la boîte (les
// partages sont à l'échelle de l'officine, pas de la boîte).
import { UpdateBoiteInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole, type Role } from '@/lib/auth/guards';
import { findBoiteById, softDeleteBoite, updateBoite } from '@/lib/boites/repo';
import { serializeBoite } from '@/lib/boites/serialize';
import { getDb } from '@/lib/db';
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

interface ResolvedBoite {
  boiteId: string;
  officineId: string;
}

async function resolveBoite(
  request: Request,
  context: RouteContext,
  allowedRoles: readonly Role[],
): Promise<{ resolved: ResolvedBoite; userId: string } | Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  const db = getDb();
  const boite = await findBoiteById(db, params.id);
  if (!boite) {
    return apiErrorResponse('not_found', 'Boîte introuvable.');
  }

  const partage = await requireRole(auth.user.id, boite.officineId, allowedRoles, {
    db,
  });
  if (partage instanceof Response) return partage;

  return {
    resolved: { boiteId: boite.id, officineId: boite.officineId },
    userId: auth.user.id,
  };
}

export async function GET(request: Request, context: RouteContext): Promise<Response> {
  const ctx = await resolveBoite(request, context, ['owner', 'editor', 'viewer']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const boite = await findBoiteById(db, ctx.resolved.boiteId);
  if (!boite) {
    return apiErrorResponse('not_found', 'Boîte introuvable.');
  }
  return Response.json(serializeBoite(boite), { status: 200 });
}

export async function PATCH(request: Request, context: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.clone().json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = UpdateBoiteInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const ctx = await resolveBoite(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const updated = await updateBoite(db, ctx.resolved.boiteId, {
    ...(parsed.data.statut !== undefined && { statut: parsed.data.statut }),
    ...(parsed.data.unites_initiales !== undefined && {
      unitesInitiales: parsed.data.unites_initiales,
    }),
    ...(parsed.data.unites_restantes !== undefined && {
      unitesRestantes: parsed.data.unites_restantes,
    }),
    ...(parsed.data.nombre_boites !== undefined && {
      nombreBoites: parsed.data.nombre_boites,
    }),
    ...(parsed.data.notes !== undefined && { notes: parsed.data.notes }),
  });
  if (!updated) {
    return apiErrorResponse('not_found', 'Boîte introuvable.');
  }
  return Response.json(serializeBoite(updated), { status: 200 });
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const ctx = await resolveBoite(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const ok = await softDeleteBoite(db, ctx.resolved.boiteId);
  if (!ok) {
    return apiErrorResponse('not_found', 'Boîte introuvable.');
  }
  return new Response(null, { status: 204 });
}
