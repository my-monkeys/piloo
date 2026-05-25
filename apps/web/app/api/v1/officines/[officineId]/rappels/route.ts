// GET (list) + POST (create) des rappels rapides d'une officine (#98).
// Le POST génère AUSSI les prises_planifiees pour les 30 prochains jours
// (#343) — au-delà, le cron generation-glissante prend le relais pour
// les rappels sans date_fin.
import { CreateRappelInputSchema } from '@piloo/api-contract';
import { prisesPlanifiees } from '@piloo/db-schema';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { generatePrisesForRappel } from '@/lib/prises/generate';
import { createRappel, listRappelsByOfficine } from '@/lib/rappels/repo';
import { serializeRappel } from '@/lib/rappels/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

/// Fenêtre initiale de génération inline (en jours). Au-delà, le cron
/// generation-glissante (#108) régénère par paliers. 30j = bon
/// compromis : couvre 1 mois de timeline immédiate sans saturer.
const INITIAL_WINDOW_DAYS = 30;

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
  // immédiatement dans la timeline Aujourd'hui (#343). On démarre au
  // max(date_debut, today) pour ne pas créer de prises dans le passé,
  // et on borne à INITIAL_WINDOW_DAYS. Si dateFin est plus proche, on
  // tronque pour ne pas dépasser.
  const today = new Date();
  const todayUtc = new Date(
    Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()),
  );
  const debutUtc = new Date(`${rappel.dateDebut}T00:00:00.000Z`);
  const windowStart = debutUtc.getTime() > todayUtc.getTime() ? debutUtc : todayUtc;
  let windowDays = INITIAL_WINDOW_DAYS;
  if (rappel.dateFin) {
    const finUtc = new Date(`${rappel.dateFin}T00:00:00.000Z`);
    // inclusif : dateFin incluse dans la fenêtre.
    const remaining = Math.floor((finUtc.getTime() - windowStart.getTime()) / 86_400_000) + 1;
    if (remaining < windowDays) windowDays = Math.max(0, remaining);
  }
  if (windowDays > 0) {
    const prises = generatePrisesForRappel(rappel, {
      officineId: params.officineId,
      windowStart,
      windowDays,
    });
    if (prises.length > 0) {
      await db.insert(prisesPlanifiees).values(prises);
    }
  }

  return Response.json(serializeRappel(rappel), { status: 201 });
}
