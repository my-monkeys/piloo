// GET (list) + POST (create) des ordonnances d'une officine (#106).
import { CreateOrdonnanceInputSchema, type CreatePrescriptionInput } from '@piloo/api-contract';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import {
  createOrdonnanceWithPrescriptions,
  listOrdonnancesByOfficine,
} from '@/lib/ordonnances/repo';
import {
  serializeOrdonnance,
  serializeOrdonnanceWithPrescriptions,
} from '@/lib/ordonnances/serialize';
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
  const partage = await requireRole(
    auth.user.id,
    params.officineId,
    ['owner', 'editor', 'viewer'],
    { db },
  );
  if (partage instanceof Response) return partage;

  const items = await listOrdonnancesByOfficine(db, params.officineId);
  return Response.json({ items: items.map(serializeOrdonnance) }, { status: 200 });
}

function toPrescriptionRow(p: CreatePrescriptionInput): {
  cip13: string | null;
  cis: string | null;
  nomTexte: string;
  posologie: CreatePrescriptionInput['posologie'];
  dureeJours: number | null;
  indication: string | null;
  notes: string | null;
} {
  return {
    cip13: p.cip13 ?? null,
    cis: p.cis ?? null,
    nomTexte: p.nom_texte,
    posologie: p.posologie,
    dureeJours: p.duree_jours ?? null,
    indication: p.indication ?? null,
    notes: p.notes ?? null,
  };
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
  const parsed = CreateOrdonnanceInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const partage = await requireRole(auth.user.id, params.officineId, ['owner', 'editor'], { db });
  if (partage instanceof Response) return partage;

  const { ordonnance, prescriptions } = await createOrdonnanceWithPrescriptions(
    db,
    {
      officineId: params.officineId,
      prescripteur: parsed.data.prescripteur ?? null,
      datePrescription: parsed.data.date_prescription,
      source: parsed.data.source ?? 'manuelle',
      photoUrl: parsed.data.photo_url ?? null,
      notes: parsed.data.notes ?? null,
      saisiePar: auth.user.id,
    },
    (parsed.data.prescriptions ?? []).map(toPrescriptionRow),
  );

  return Response.json(serializeOrdonnanceWithPrescriptions(ordonnance, prescriptions), {
    status: 201,
  });
}
