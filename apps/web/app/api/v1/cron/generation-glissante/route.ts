// Endpoint cron génération glissante (#108).
// Auth : Bearer CRON_SECRET. Schedule : quotidien (vercel.json).
import { runGenerationGlissanteCron } from '@/lib/prises/cron-glissant';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.generation_glissante.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }
  const result = await runGenerationGlissanteCron(getDb());
  return Response.json(result, { status: 200 });
}
