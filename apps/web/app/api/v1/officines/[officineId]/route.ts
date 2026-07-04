// GET / PATCH / DELETE /api/v1/officines/:id (#70).
import { UpdateOfficineInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { findOfficineById, softDeleteOfficine, updateOfficine } from '@/lib/officines/repo';
import { serializeOfficine } from '@/lib/officines/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ officineId: z.uuid() });

interface RouteContext {
  params: Promise<{ officineId: string }>;
}

async function parseParams(context: RouteContext): Promise<{ officineId: string } | Response> {
  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }
  return parsed.data;
}

export async function GET(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  const db = getDb();
  // Lecture autorisée pour les 3 rôles (viewer inclus).
  const partage = await requireRole(
    auth.user.id,
    params.officineId,
    ['owner', 'editor', 'viewer'],
    { db },
  );
  if (partage instanceof Response) return partage;

  const officine = await findOfficineById(db, params.officineId);
  if (!officine) {
    return apiErrorResponse('not_found', 'Officine introuvable.');
  }
  return Response.json(serializeOfficine(officine, partage.role), {
    status: 200,
  });
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
  const parsed = UpdateOfficineInputSchema.safeParse(body);
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }

  const db = getDb();
  // Update autorisé aux owner et editor (cf. docs/spec.md §"Partages").
  const partage = await requireRole(auth.user.id, params.officineId, ['owner', 'editor'], { db });
  if (partage instanceof Response) return partage;

  const updated = await updateOfficine(db, params.officineId, {
    ...(parsed.data.nom !== undefined && { nom: parsed.data.nom }),
    ...(parsed.data.date_naissance !== undefined && {
      dateNaissance: parsed.data.date_naissance,
    }),
    ...(parsed.data.notes !== undefined && { notes: parsed.data.notes }),
    ...(parsed.data.timezone !== undefined && { timezone: parsed.data.timezone }),
  });

  if (!updated) {
    return apiErrorResponse('not_found', 'Officine introuvable.');
  }
  return Response.json(serializeOfficine(updated, partage.role), {
    status: 200,
  });
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  const db = getDb();
  // Suppression réservée au propriétaire (cf. docs/spec.md §"Partages").
  const partage = await requireRole(auth.user.id, params.officineId, ['owner'], { db });
  if (partage instanceof Response) return partage;

  const deleted = await softDeleteOfficine(db, params.officineId);
  if (!deleted) {
    return apiErrorResponse('not_found', 'Officine introuvable.');
  }
  return new Response(null, { status: 204 });
}
