// GET / PATCH / DELETE /api/v1/ordonnances/:id (#106).
import { UpdateOrdonnanceInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole, type Role } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import {
  findOrdonnanceById,
  listPrescriptionsByOrdonnance,
  softDeleteOrdonnance,
  updateOrdonnance,
} from '@/lib/ordonnances/repo';
import {
  serializeOrdonnance,
  serializeOrdonnanceWithPrescriptions,
} from '@/lib/ordonnances/serialize';
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

interface Resolved {
  ordonnanceId: string;
  officineId: string;
}

async function resolveOrdonnance(
  request: Request,
  context: RouteContext,
  allowedRoles: readonly Role[],
): Promise<{ resolved: Resolved; userId: string } | Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  const db = getDb();
  const ord = await findOrdonnanceById(db, params.id);
  if (!ord) {
    return apiErrorResponse('not_found', 'Ordonnance introuvable.');
  }

  const partage = await requireRole(auth.user.id, ord.officineId, allowedRoles, { db });
  if (partage instanceof Response) return partage;

  return {
    resolved: { ordonnanceId: ord.id, officineId: ord.officineId },
    userId: auth.user.id,
  };
}

export async function GET(request: Request, context: RouteContext): Promise<Response> {
  const ctx = await resolveOrdonnance(request, context, ['owner', 'editor', 'viewer']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const ord = await findOrdonnanceById(db, ctx.resolved.ordonnanceId);
  if (!ord) {
    return apiErrorResponse('not_found', 'Ordonnance introuvable.');
  }
  const prescs = await listPrescriptionsByOrdonnance(db, ord.id);
  return Response.json(serializeOrdonnanceWithPrescriptions(ord, prescs), { status: 200 });
}

export async function PATCH(request: Request, context: RouteContext): Promise<Response> {
  let body: unknown;
  try {
    body = await request.clone().json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = UpdateOrdonnanceInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const ctx = await resolveOrdonnance(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const updated = await updateOrdonnance(db, ctx.resolved.ordonnanceId, {
    ...(parsed.data.prescripteur !== undefined && { prescripteur: parsed.data.prescripteur }),
    ...(parsed.data.date_prescription !== undefined && {
      datePrescription: parsed.data.date_prescription,
    }),
    ...(parsed.data.photo_url !== undefined && { photoUrl: parsed.data.photo_url }),
    ...(parsed.data.notes !== undefined && { notes: parsed.data.notes }),
  });
  if (!updated) {
    return apiErrorResponse('not_found', 'Ordonnance introuvable.');
  }
  return Response.json(serializeOrdonnance(updated), { status: 200 });
}

export async function DELETE(request: Request, context: RouteContext): Promise<Response> {
  const ctx = await resolveOrdonnance(request, context, ['owner', 'editor']);
  if (ctx instanceof Response) return ctx;

  const db = getDb();
  const ok = await softDeleteOrdonnance(db, ctx.resolved.ordonnanceId);
  if (!ok) {
    return apiErrorResponse('not_found', 'Ordonnance introuvable.');
  }
  return new Response(null, { status: 204 });
}
