// GET (list) + POST (create) des rappels rapides d'une officine (#98).
// Le POST génère AUSSI les prises_planifiees pour les 30 prochains jours
// (#343) — au-delà, le cron generation-glissante prend le relais pour
// les rappels sans date_fin.
import { CreateRappelInputSchema } from '@piloo/api-contract';
import { prisesPlanifiees } from '@piloo/db-schema';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { buildInitialRappelPrises } from '@/lib/rappels/reconcile';
import { createRappel, listRappelsByOfficine } from '@/lib/rappels/repo';
import { serializeRappel } from '@/lib/rappels/serialize';
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

  const items = await listRappelsByOfficine(db, params.officineId);
  return Response.json({ items: items.map(serializeRappel) }, { status: 200 });
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
  const parsed = CreateRappelInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const partage = await requireRole(auth.user.id, params.officineId, ['owner', 'editor'], { db });
  if (partage instanceof Response) return partage;

  const rappel = await createRappel(db, {
    officineId: params.officineId,
    cip13: parsed.data.cip13,
    nomTexte: parsed.data.nom_texte,
    unite: parsed.data.unite ?? 'comprimé',
    quantiteMatin: parsed.data.quantite_matin ?? null,
    quantiteMidi: parsed.data.quantite_midi ?? null,
    quantiteSoir: parsed.data.quantite_soir ?? null,
    quantiteCoucher: parsed.data.quantite_coucher ?? null,
    dateDebut: parsed.data.date_debut,
    dateFin: parsed.data.date_fin ?? null,
    notes: parsed.data.notes ?? null,
    creeParUserId: auth.user.id,
  });

  // Génération inline des prises pour rendre le rappel visible
  // immédiatement dans la timeline Aujourd'hui (#343). La logique de
  // fenêtrage (max(date_debut, today), borne dateFin) est centralisée
  // dans buildInitialRappelPrises pour rester DRY avec la réconciliation.
  const prises = buildInitialRappelPrises(rappel);
  if (prises.length > 0) {
    await db.insert(prisesPlanifiees).values(prises);
  }

  return Response.json(serializeRappel(rappel), { status: 201 });
}
