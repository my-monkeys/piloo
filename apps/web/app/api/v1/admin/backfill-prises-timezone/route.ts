// Endpoint admin one-shot : backfill des prises futures au fuseau officine
// (#363). Auth : Bearer CRON_SECRET. À déclencher une fois post-deploy.
import { getDb } from '@/lib/db';
import { runBackfillPrisesTimezone } from '@/lib/prises/backfill-timezone';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('admin.backfill_prises_timezone.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification invalide.');
  }
  const result = await runBackfillPrisesTimezone(getDb());
  log.info('admin.backfill_prises_timezone.done', result);
  return Response.json(result, { status: 200 });
}
