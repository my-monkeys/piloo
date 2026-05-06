// GET (list) + POST (create) des boîtes d'une officine (#86).
import { CreateBoiteInputSchema } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { createBoite, listBoitesByOfficine } from '@/lib/boites/repo';
import { serializeBoite } from '@/lib/boites/serialize';
import { getDb } from '@/lib/db';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ officineId: z.uuid() });

interface RouteContext {
  params: Promise<{ officineId: string }>;
}

async function parseParams(context: RouteContext): Promise<{ officineId: string } | Response> {
  const raw = await context.params;
  const parsed = ParamsSchema.safeParse(raw);
  if (!parsed.success) return zodErrorResponse(parsed.error);
  return parsed.data;
}

export async function GET(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const params = await parseParams(context);
  if (params instanceof Response) return params;

  const db = getDb();
  // Lecture autorisée pour les 3 rôles.
  const partage = await requireRole(
    auth.user.id,
    params.officineId,
    ['owner', 'editor', 'viewer'],
    { db },
  );
  if (partage instanceof Response) return partage;

  const items = await listBoitesByOfficine(db, params.officineId);
  return Response.json({ items: items.map(serializeBoite) }, { status: 200 });
}

export async function POST(request: Request, context: RouteContext): Promise<Response> {
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
  const parsed = CreateBoiteInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  // Création réservée aux owner/editor (cf. docs/spec.md §"Partages").
  const partage = await requireRole(auth.user.id, params.officineId, ['owner', 'editor'], { db });
  if (partage instanceof Response) return partage;

  const boite = await createBoite(db, {
    officineId: params.officineId,
    cip13: parsed.data.cip13,
    lot: parsed.data.lot ?? null,
    numeroSerie: parsed.data.numero_serie ?? null,
    peremption: parsed.data.peremption,
    unitesInitiales: parsed.data.unites_initiales ?? null,
    unitesRestantes: parsed.data.unites_restantes ?? null,
    notes: parsed.data.notes ?? null,
    ajouteePar: auth.user.id,
  });
  return Response.json(serializeBoite(boite), { status: 201 });
}
