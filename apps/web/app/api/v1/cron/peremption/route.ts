// Endpoint cron quotidien péremption (#143).
//
// Authentification : header `Authorization: Bearer <CRON_SECRET>`.
// Le secret est partagé entre Vercel Cron (ou tout scheduler externe)
// et l'env de l'app. Pas d'auth user : c'est un job machine.
import { runPeremptionCron } from '@/lib/alertes/peremption';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.peremption.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }

  const db = getDb();
  const result = await runPeremptionCron(db);
  return Response.json(result, { status: 200 });
}
