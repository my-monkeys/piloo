// Schéma du endpoint GET /health — POC qui valide la chaîne Zod → OpenAPI →
// types TS / Dart. Cf. ticket #37 pour l'implémentation côté apps/web.
import { z } from 'zod';

import { registry } from '../openapi.ts';

export const HealthResponseSchema = z
  .object({
    status: z.enum(['ok', 'degraded']).openapi({ example: 'ok' }),
    version: z.string().openapi({ example: '0.0.0' }),
    timestamp: z.iso.datetime().openapi({ example: '2026-05-02T12:00:00.000Z' }),
  })
  .openapi('HealthResponse');

export type HealthResponse = z.infer<typeof HealthResponseSchema>;

registry.registerPath({
  method: 'get',
  path: '/health',
  summary: 'Liveness probe',
  description:
    'Renvoie le statut du serveur. Utilisé par les health checks Vercel et le monitoring.',
  tags: ['health'],
  responses: {
    200: {
      description: 'Serveur OK',
      content: {
        'application/json': {
          schema: HealthResponseSchema,
        },
      },
    },
  },
});
