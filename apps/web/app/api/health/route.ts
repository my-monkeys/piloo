// GET /api/health — POC qui valide la chaîne Zod côté serveur (#37).
// La réponse est construite puis re-validée via HealthResponseSchema avant
// envoi : si le serveur produit un payload non conforme au contrat, on
// renvoie un 400 structuré au lieu d'un 200 incorrect (cohérence avec les
// types générés côté clients).
import { type HealthResponse, HealthResponseSchema } from '@piloo/api-contract';

import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export function GET(): Response {
  const payload: HealthResponse = {
    status: 'ok',
    version: process.env['npm_package_version'] ?? '0.0.0',
    timestamp: new Date().toISOString(),
  };

  const parsed = HealthResponseSchema.safeParse(payload);
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }
  return Response.json(parsed.data, { status: 200 });
}

export function POST(): Response {
  return apiErrorResponse('not_found', 'Method not allowed on /api/health.');
}
