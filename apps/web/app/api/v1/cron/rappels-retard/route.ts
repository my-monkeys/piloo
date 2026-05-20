// Endpoint cron rappels prises en retard (#130).
//
// Authentification : Bearer CRON_SECRET. Fréquence : toutes les
// 15 min (cf. vercel.json) pour rattraper les prises qui dépassent
// +30min sans validation, avant que le cron prise-oubliee #118
// les flip à oubliee à +1h.
import { runRappelsRetardCron } from '@/lib/notifications/rappels-retard';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';
export const maxDuration = 30;

export async function GET(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.rappels_retard.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }
  const result = await runRappelsRetardCron(getDb());
  return Response.json(result, { status: 200 });
}
