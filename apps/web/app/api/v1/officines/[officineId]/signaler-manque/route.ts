// POST /api/v1/officines/:officineId/signaler-manque (#147).
//
// Tout membre (owner/editor/viewer) peut signaler un manque. Crée une
// alerte `manque_signale` pour chaque owner/editor de l'officine,
// sauf le signaleur lui-même (il sait qu'il vient de signaler).
import { SignalerManqueInputSchema, type SignalerManqueResponse } from '@piloo/api-contract';
import { alertes, officines, partages } from '@piloo/db-schema';
import { and, eq, isNull, or } from 'drizzle-orm';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ officineId: z.uuid() });

interface RouteContext {
  params: Promise<{ officineId: string }>;
}

export async function POST(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const rawParams = await context.params;
  const paramsParsed = ParamsSchema.safeParse(rawParams);
  if (!paramsParsed.success) return zodErrorResponse(paramsParsed.error);
  const { officineId } = paramsParsed.data;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = SignalerManqueInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  // Le signaleur doit appartenir à l'officine (n'importe quel rôle).
  const partage = await requireRole(auth.user.id, officineId, ['owner', 'editor', 'viewer'], {
    db,
  });
  if (partage instanceof Response) return partage;

  // Destinataires : owner officine + partages owner/editor actifs,
  // sauf l'auteur du signalement.
  const [officineRow] = await db
    .select({ proprietaireUserId: officines.proprietaireUserId })
    .from(officines)
    .where(and(eq(officines.id, officineId), isNull(officines.deletedAt)))
    .limit(1);
  if (!officineRow) {
    return apiErrorResponse('not_found', 'Officine introuvable.');
  }

  const partageRows = await db
    .select({ userId: partages.userId })
    .from(partages)
    .where(
      and(
        eq(partages.officineId, officineId),
        isNull(partages.deletedAt),
        or(eq(partages.role, 'owner'), eq(partages.role, 'editor')),
      ),
    );

  const recipients = new Set<string>([officineRow.proprietaireUserId]);
  for (const r of partageRows) recipients.add(r.userId);
  recipients.delete(auth.user.id);

  if (recipients.size === 0) {
    // Cas typique : owner solo qui signale tout seul → personne à
    // notifier. On répond 201 avec 0 alertes pour rester idempotent.
    log.info('manque.no_recipients', { officineId });
    const empty: SignalerManqueResponse = { alertes_creees: 0 };
    return Response.json(empty, { status: 201 });
  }

  await db.insert(alertes).values(
    [...recipients].map((userId) => ({
      officineId,
      userId,
      type: 'manque_signale' as const,
      payload: {
        signale_par: auth.user.id,
        ...(parsed.data.cip13 !== undefined && { cip13: parsed.data.cip13 }),
        ...(parsed.data.libelle !== undefined && { libelle: parsed.data.libelle }),
        ...(parsed.data.message !== undefined && { message: parsed.data.message }),
      },
    })),
  );

  log.info('manque.created', {
    officineId,
    recipients: recipients.size,
  });

  const out: SignalerManqueResponse = { alertes_creees: recipients.size };
  return Response.json(out, { status: 201 });
}
