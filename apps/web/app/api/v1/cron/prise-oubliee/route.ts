// Endpoint cron prises oubliées (#118).
//
// Authentification : header `Authorization: Bearer <CRON_SECRET>`.
// Le secret est partagé entre Vercel Cron (ou tout scheduler externe)
// et l'env de l'app. Pas d'auth user : c'est un job machine.
//
// Fréquence : toutes les 15 minutes (cf. vercel.json). La granularité
// fine évite qu'une prise reste plus de ~15min en `prevue` après son
// expiration de la grace period 1h.
import { runPriseOublieeCron } from '@/lib/alertes/prise-oubliee';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.prise_oubliee.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }

  const db = getDb();
  const result = await runPriseOublieeCron(db);
  return Response.json(result, { status: 200 });
}
