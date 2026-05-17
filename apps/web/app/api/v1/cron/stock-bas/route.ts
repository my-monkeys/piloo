// Endpoint cron stock bas (#145).
//
// Authentification : header `Authorization: Bearer <CRON_SECRET>`.
// Fréquence : quotidienne (cf. vercel.json). Pas besoin de plus fin
// — le stock évolue lentement, et un alerte 1 fois par jour est l'UX
// attendue.
import { runStockBasCron } from '@/lib/alertes/stock-bas';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.stock_bas.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }
  const result = await runStockBasCron(getDb());
  return Response.json(result, { status: 200 });
}
