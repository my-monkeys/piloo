// PATCH / DELETE /api/v1/prescriptions/:id (#106).
import { UpdatePrescriptionInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole, type Role } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import {
  findOrdonnanceById,
  findPrescriptionById,
  softDeletePrescription,
  updatePrescription,
} from '@/lib/ordonnances/repo';
import { serializePrescription } from '@/lib/ordonnances/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ id: z.uuid() });

interface RouteContext {
  params: Promise<{ id: string }>;
}

interface Resolved {
  prescriptionId: string;
  officineId: string;
}

async function resolvePrescription(
  request: Request,
  context: RouteContext,
  allowedRoles: readonly Role[],
): Promise<{ resolved: Resolved; userId: string } | Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const rawParams = await context.params;
  const parsedParams = ParamsSchema.safeParse(rawParams);
  if (!parsedParams.success) return zodErrorResponse(parsedParams.error);

  const db = getDb();
  const presc = await findPrescriptionById(db, parsedParams.data.id);
  if (!presc) {
    return apiErrorResponse('not_found', 'Prescription introuvable.');
  }
  // Le rôle est résolu sur l'officine via l'ordonnance parente.
  const ord = await findOrdonnanceById(db, presc.ordonnanceId);
  if (!ord) {
    return apiErrorResponse('not_found', 'Prescription introuvable.');
  }
  const partage = await requireRole(auth.user.id, ord.officineId, allowedRoles, { db });
  if (partage instanceof Response) return partage;

  return {
    resolved: { prescriptionId: presc.id, officineId: ord.officineId },
    userId: auth.user.id,
  };
}

export async function PATCH(request: Request, context: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.clone().json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = UpdatePrescriptionInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const ctx = await resolvePrescription(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const updated = await updatePrescription(db, ctx.resolved.prescriptionId, {
    ...(parsed.data.cip13 !== undefined && { cip13: parsed.data.cip13 }),
    ...(parsed.data.cis !== undefined && { cis: parsed.data.cis }),
    ...(parsed.data.nom_texte !== undefined && { nomTexte: parsed.data.nom_texte }),
    ...(parsed.data.posologie !== undefined && { posologie: parsed.data.posologie }),
    ...(parsed.data.duree_jours !== undefined && { dureeJours: parsed.data.duree_jours }),
    ...(parsed.data.indication !== undefined && { indication: parsed.data.indication }),
    ...(parsed.data.notes !== undefined && { notes: parsed.data.notes }),
  });
  if (!updated) {
    return apiErrorResponse('not_found', 'Prescription introuvable.');
  }
  return Response.json(serializePrescription(updated), { status: 200 });
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const ctx = await resolvePrescription(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const ok = await softDeletePrescription(db, ctx.resolved.prescriptionId);
  if (!ok) {
    return apiErrorResponse('not_found', 'Prescription introuvable.');
  }
  return new Response(null, { status: 204 });
}
