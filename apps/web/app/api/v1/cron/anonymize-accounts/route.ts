// Cron quotidien d'anonymisation des comptes au-delà du délai 7 jours (#159).
import { anonymizeExpiredAccounts } from '@/lib/me/delete';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.anonymize_accounts.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }
  const result = await anonymizeExpiredAccounts(getDb());
  return Response.json(result, { status: 200 });
}
