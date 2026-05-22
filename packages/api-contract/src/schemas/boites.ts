// Schémas Zod du contrat /api/v1/.../boites (#86).
// Cf. docs/api-contract.md §"Boîtes" + docs/data-model.md §"boites".
import { z } from 'zod';

import { registry } from '../openapi.ts';

const StatutBoiteEnum = z.enum(['active', 'vide', 'perimee']);
const Cip13 = z.string().regex(/^\d{13}$/, 'cip13 doit faire 13 chiffres');

export const BoiteSchema = z
  .object({
    id: z.uuid(),
    officine_id: z.uuid(),
    cip13: Cip13,
    lot: z.string().max(64).nullable(),
    numero_serie: z.string().max(64).nullable(),
    peremption: z.iso.date(),
    unites_initiales: z.number().int().positive().nullable(),
    unites_restantes: z.number().int().min(0).nullable(),
    nombre_boites: z.number().int().min(1),
    statut: StatutBoiteEnum,
    notes: z.string().max(2000).nullable(),
    ajoutee_par: z.uuid(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    deleted_at: z.iso.datetime().nullable(),
  })
  .openapi('Boite');

export const CreateBoiteInputSchema = z
  .object({
    cip13: Cip13,
    lot: z.string().max(64).nullable().optional(),
    numero_serie: z.string().max(64).nullable().optional(),
    peremption: z.iso.date(),
    unites_initiales: z.number().int().positive().nullable().optional(),
    unites_restantes: z.number().int().min(0).nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
  })
  .openapi('CreateBoiteInput');

export const UpdateBoiteInputSchema = z
  .object({
    statut: StatutBoiteEnum.optional(),
    unites_initiales: z.number().int().positive().nullable().optional(),
    unites_restantes: z.number().int().min(0).nullable().optional(),
    nombre_boites: z.number().int().min(1).optional(),
    notes: z.string().max(2000).nullable().optional(),
  })
  .openapi('UpdateBoiteInput');

export const ListBoitesResponseSchema = z
  .object({
    items: z.array(BoiteSchema),
  })
  .openapi('ListBoitesResponse');

export type Boite = z.infer<typeof BoiteSchema>;
export type CreateBoiteInput = z.infer<typeof CreateBoiteInputSchema>;
export type UpdateBoiteInput = z.infer<typeof UpdateBoiteInputSchema>;
export type ListBoitesResponse = z.infer<typeof ListBoitesResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('BoiteApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/officines/{officineId}/boites',
  summary: "Liste les boîtes d'une officine",
  description: 'Renvoie les boîtes non soft-deleted, triées par création décroissante.',
  tags: ['boites'],
  request: { params: z.object({ officineId: z.uuid() }) },
  responses: {
    200: {
      description: 'Liste',
      content: { 'application/json': { schema: ListBoitesResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès à l'officine"),
    404: errorResponse('Officine introuvable'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/officines/{officineId}/boites',
  summary: 'Crée une boîte dans une officine',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['boites'],
  request: {
    params: z.object({ officineId: z.uuid() }),
    body: { content: { 'application/json': { schema: CreateBoiteInputSchema } } },
  },
  responses: {
    201: {
      description: 'Boîte créée',
      content: { 'application/json': { schema: BoiteSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Officine introuvable'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/boites/{id}',
  summary: "Détail d'une boîte",
  tags: ['boites'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    200: {
      description: 'Détail',
      content: { 'application/json': { schema: BoiteSchema } },
    },
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès"),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/boites/{id}',
  summary: 'Met à jour une boîte (stock, statut, notes)',
  description: "Réservé aux rôles owner et editor sur l'officine de la boîte.",
  tags: ['boites'],
  request: {
    params: z.object({ id: z.uuid() }),
    body: { content: { 'application/json': { schema: UpdateBoiteInputSchema } } },
  },
  responses: {
    200: {
      description: 'Boîte mise à jour',
      content: { 'application/json': { schema: BoiteSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/boites/{id}',
  summary: 'Supprime (soft-delete) une boîte',
  description: "Réservé aux rôles owner et editor sur l'officine de la boîte.",
  tags: ['boites'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Supprimée' },
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});
