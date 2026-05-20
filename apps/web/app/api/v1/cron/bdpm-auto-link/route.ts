// Cron auto-link rétroactif BDPM (#55).
//
// Fréquence : déclenché après le cron mensuel d'import BDPM
// (`/api/cron/import-bdpm`) — soit en chaîne dans Vercel cron, soit
// déclenché par le step précédent. Voir vercel.json.
//
// But : récupérer les boîtes orphelines (notes commençant par "CIP <…>")
// dont le CIP est maintenant connu de la BDPM mise à jour, et leur
// remettre le vrai nom.
import { runBdpmAutoLink } from '@/lib/bdpm/auto-link';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';
// ~80k boîtes potentiellement à scanner en cas de gros base — on garde
// une marge confortable.
export const maxDuration = 60;

export async function GET(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.bdpm_auto_link.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }
  log.info('cron.bdpm_auto_link.start', {});
  const result = await runBdpmAutoLink(getDb());
  log.info('cron.bdpm_auto_link.done', result);
  return Response.json(result, { status: 200 });
}
