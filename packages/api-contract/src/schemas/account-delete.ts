// OpenAPI suppression compte (#159).
import { z } from 'zod';

import { registry } from '../openapi.ts';

const DeleteResponseSchema = z
  .object({
    deleted_at: z.iso.datetime(),
    scheduled_anonymization_at: z.iso.datetime(),
  })
  .openapi('AccountDeleteResponse');

const RestoreResponseSchema = z
  .object({ restored: z.literal(true) })
  .openapi('AccountRestoreResponse');

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('AccountDeleteApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'post',
  path: '/v1/me/delete',
  summary: 'Déclenche la suppression du compte (délai 7 jours)',
  description:
    "Le compte reste utilisable pendant 7 jours, le temps de pouvoir l'annuler via /v1/me/restore. Au-delà, anonymisation automatique par cron.",
  tags: ['rgpd'],
  responses: {
    200: {
      description: 'Demande enregistrée',
      content: { 'application/json': { schema: DeleteResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/me/restore',
  summary: 'Annule une demande de suppression en cours',
  tags: ['rgpd'],
  responses: {
    200: {
      description: 'Compte restauré',
      content: { 'application/json': { schema: RestoreResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
    404: errorResponse('Aucune suppression en cours'),
  },
});
