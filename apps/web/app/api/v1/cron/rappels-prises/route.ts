// Cron rappels prises (#126).
//
// Vercel Cron → GET avec Authorization: Bearer CRON_SECRET.
//
// Schedule recommandé : `*/5 * * * *` (toutes les 5 min) sur Pro tier.
// Sur Hobby (1 cron/jour max), passer le scheduler en device-local via
// flutter_local_notifications côté mobile (TODO #128) — ce endpoint
// reste utilisable manuellement ou pour les comptes pro.
import { getDb } from '@/lib/db';
import { runRappelsCron } from '@/lib/notifications/rappels';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';
export const maxDuration = 60;

export async function GET(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.rappels.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }
  const result = await runRappelsCron(getDb());
  return Response.json(result, { status: 200 });
}
