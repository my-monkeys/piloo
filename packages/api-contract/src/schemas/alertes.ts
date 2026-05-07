// Schémas Zod /api/v1/alertes (#140).
//
// Endpoints :
//   GET /alertes?cursor=&limit=&type=&unread_only=
//     Liste paginée des alertes du user courant (toutes officines).
//   POST /alertes/:id/read
//     Marque une alerte comme lue (idempotent).
//
// Pagination cursor-based : on retourne `next_cursor` opaque (createdAt
// + id du dernier item) si la page est pleine, null sinon.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const TypeAlerteEnum = z.enum([
  'peremption_30j',
  'peremption_7j',
  'stock_bas',
  'prise_oubliee',
  'manque_signale',
]);

export const AlerteSchema = z
  .object({
    id: z.uuid(),
    officine_id: z.uuid(),
    user_id: z.uuid(),
    type: TypeAlerteEnum,
    payload: z.record(z.string(), z.unknown()),
    lue_a: z.iso.datetime().nullable(),
    created_at: z.iso.datetime(),
  })
  .openapi('Alerte');

export const ListAlertesQuerySchema = z
  .object({
    cursor: z.string().optional(),
    limit: z.coerce.number().int().min(1).max(100).optional(),
    type: TypeAlerteEnum.optional(),
    unread_only: z
      .enum(['true', 'false'])
      .transform((v) => v === 'true')
      .optional(),
  })
  .openapi('ListAlertesQuery');

export const ListAlertesResponseSchema = z
  .object({
    items: z.array(AlerteSchema),
    next_cursor: z.string().nullable(),
  })
  .openapi('ListAlertesResponse');

export type Alerte = z.infer<typeof AlerteSchema>;
export type ListAlertesQuery = z.infer<typeof ListAlertesQuerySchema>;
export type ListAlertesResponse = z.infer<typeof ListAlertesResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('AlertesApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/alertes',
  summary: "Liste paginée des alertes de l'utilisateur",
  description:
    'Filtres optionnels par type et lues/non lues. Pagination cursor-based : passer `cursor` reçu dans `next_cursor` à la réponse précédente.',
  tags: ['alertes'],
  request: { query: ListAlertesQuerySchema },
  responses: {
    200: {
      description: 'Page',
      content: { 'application/json': { schema: ListAlertesResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
    400: errorResponse('Cursor ou paramètres invalides'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/alertes/{id}/read',
  summary: 'Marque une alerte comme lue',
  description: "Idempotent : si l'alerte est déjà marquée lue, on retourne 204 sans modifier.",
  tags: ['alertes'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Lue' },
    401: errorResponse('Non authentifié'),
    404: errorResponse('Alerte inconnue ou non destinée à cet utilisateur'),
  },
});
