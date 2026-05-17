// POST /api/v1/ordonnances/:id/prescriptions — ajoute une prescription
// à une ordonnance existante (#106).
import { CreatePrescriptionInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { createPrescription, findOrdonnanceById } from '@/lib/ordonnances/repo';
import { serializePrescription } from '@/lib/ordonnances/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ id: z.uuid() });

interface RouteContext {
  params: Promise<{ id: string }>;
}

export async function POST(request: Request, context: RouteContext): Promise<Response> {
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
  const parsed = CreatePrescriptionInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const ord = await findOrdonnanceById(db, parsedParams.data.id);
  if (!ord) {
    return apiErrorResponse('not_found', 'Ordonnance introuvable.');
  }
  const partage = await requireRole(auth.user.id, ord.officineId, ['owner', 'editor'], { db });
  if (partage instanceof Response) return partage;

  const presc = await createPrescription(db, {
    ordonnanceId: ord.id,
    cip13: parsed.data.cip13 ?? null,
    cis: parsed.data.cis ?? null,
    nomTexte: parsed.data.nom_texte,
    posologie: parsed.data.posologie,
    dureeJours: parsed.data.duree_jours ?? null,
    indication: parsed.data.indication ?? null,
    notes: parsed.data.notes ?? null,
  });
  return Response.json(serializePrescription(presc), { status: 201 });
}
