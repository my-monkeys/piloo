// Schémas Zod du contrat /api/v1/rappels (#327).
//
// Rappels simples sans ordonnance — cf. packages/db-schema/src/schema/rappels.ts
// pour la motivation produit. MVP : daily uniquement.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const RecurrenceTypeEnum = z.enum(['daily']);

// HH:MM ou HH:MM:SS, validation stricte pour ne pas accepter
// d'inputs farfelus. Postgres stocke en `time` (HH:MM:SS), on
// normalise côté serveur si l'user envoie HH:MM.
const HeureRegex = /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/;
const HeureSchema = z.string().regex(HeureRegex, 'HH:MM ou HH:MM:SS attendu');

export const RappelSchema = z
  .object({
    id: z.uuid(),
    user_id: z.uuid(),
    officine_id: z.uuid().nullable(),
    boite_id: z.uuid().nullable(),
    label: z.string().min(1).max(120),
    heure: HeureSchema,
    recurrence_type: RecurrenceTypeEnum,
    actif: z.boolean(),
    notes: z.string().nullable(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
  })
  .openapi('Rappel');

export const CreateRappelInputSchema = z
  .object({
    label: z.string().min(1).max(120),
    heure: HeureSchema,
    officine_id: z.uuid().optional(),
    boite_id: z.uuid().optional(),
    recurrence_type: RecurrenceTypeEnum.optional().default('daily'),
    notes: z.string().max(500).optional(),
  })
  .openapi('CreateRappelInput');

export const UpdateRappelInputSchema = z
  .object({
    label: z.string().min(1).max(120).optional(),
    heure: HeureSchema.optional(),
    actif: z.boolean().optional(),
    boite_id: z.uuid().nullable().optional(),
    notes: z.string().max(500).nullable().optional(),
  })
  .openapi('UpdateRappelInput');

export const ListRappelsResponseSchema = z
  .object({ items: z.array(RappelSchema) })
  .openapi('ListRappelsResponse');

export type Rappel = z.infer<typeof RappelSchema>;
export type CreateRappelInput = z.infer<typeof CreateRappelInputSchema>;
export type UpdateRappelInput = z.infer<typeof UpdateRappelInputSchema>;
export type ListRappelsResponse = z.infer<typeof ListRappelsResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('RappelsApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/rappels',
  summary: "Liste les rappels (actifs et inactifs) de l'utilisateur courant",
  tags: ['rappels'],
  responses: {
    200: {
      description: 'Liste',
      content: { 'application/json': { schema: ListRappelsResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/rappels',
  summary: 'Crée un nouveau rappel',
  tags: ['rappels'],
  request: {
    body: { content: { 'application/json': { schema: CreateRappelInputSchema } } },
  },
  responses: {
    201: {
      description: 'Rappel créé',
      content: { 'application/json': { schema: RappelSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/rappels/{id}',
  summary: 'Met à jour un rappel (toggle actif, change heure, etc.)',
  tags: ['rappels'],
  request: {
    params: z.object({ id: z.uuid() }),
    body: { content: { 'application/json': { schema: UpdateRappelInputSchema } } },
  },
  responses: {
    200: {
      description: 'Rappel mis à jour',
      content: { 'application/json': { schema: RappelSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    404: errorResponse('Rappel inconnu ou pas au user courant'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/rappels/{id}',
  summary: 'Supprime (soft-delete) un rappel',
  tags: ['rappels'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Supprimé' },
    401: errorResponse('Non authentifié'),
    404: errorResponse('Rappel inconnu ou pas au user courant'),
  },
});
