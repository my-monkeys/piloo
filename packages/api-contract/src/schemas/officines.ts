// Schémas Zod du contrat /api/v1/officines (#70).
//
// Cf. docs/api-contract.md §"Officines" pour la liste des endpoints
// et docs/data-model.md §"officines" pour le modèle.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const TypeOfficineEnum = z.enum(['perso', 'patient']);

export const OfficineSchema = z
  .object({
    id: z.uuid(),
    nom: z.string().min(1).max(120),
    type: TypeOfficineEnum,
    proprietaire_user_id: z.uuid(),
    date_naissance: z.iso.date().nullable(),
    notes: z.string().max(2000).nullable(),
    // Fuseau IANA du carnet (#363) — planifie/affiche les prises. Défaut
    // Europe/Paris côté serveur.
    timezone: z.string().min(1).max(64),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    deleted_at: z.iso.datetime().nullable(),
    // Joint via partages — exposé pour que le client sache quel rôle
    // l'utilisateur courant a sur l'officine listée.
    role: z.enum(['owner', 'editor', 'viewer']),
  })
  .openapi('Officine');

export const CreateOfficineInputSchema = z
  .object({
    nom: z.string().min(1).max(120),
    type: TypeOfficineEnum,
    date_naissance: z.iso.date().nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
    // Fuseau IANA déduit du device à la création (#363). Omis → défaut
    // serveur Europe/Paris.
    timezone: z.string().min(1).max(64).optional(),
  })
  .openapi('CreateOfficineInput');

export const UpdateOfficineInputSchema = z
  .object({
    nom: z.string().min(1).max(120).optional(),
    date_naissance: z.iso.date().nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
    // Changement de fuseau via les réglages officine (#363).
    timezone: z.string().min(1).max(64).optional(),
  })
  .openapi('UpdateOfficineInput');

export const ListOfficinesResponseSchema = z
  .object({
    items: z.array(OfficineSchema),
  })
  .openapi('ListOfficinesResponse');

export type Officine = z.infer<typeof OfficineSchema>;
export type CreateOfficineInput = z.infer<typeof CreateOfficineInputSchema>;
export type UpdateOfficineInput = z.infer<typeof UpdateOfficineInputSchema>;
export type ListOfficinesResponse = z.infer<typeof ListOfficinesResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('ApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/officines',
  summary: "Liste les officines accessibles à l'utilisateur courant",
  description:
    "Renvoie les officines dont l'utilisateur est propriétaire OU sur lesquelles il a un partage actif.",
  tags: ['officines'],
  responses: {
    200: {
      description: 'Liste',
      content: { 'application/json': { schema: ListOfficinesResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/officines',
  summary: 'Crée une officine',
  description:
    "L'utilisateur courant devient propriétaire et un partage owner est créé automatiquement.",
  tags: ['officines'],
  request: {
    body: {
      content: { 'application/json': { schema: CreateOfficineInputSchema } },
    },
  },
  responses: {
    201: {
      description: 'Officine créée',
      content: { 'application/json': { schema: OfficineSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/officines/{id}',
  summary: "Détail d'une officine",
  tags: ['officines'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    200: {
      description: 'Détail',
      content: { 'application/json': { schema: OfficineSchema } },
    },
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès"),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/officines/{id}',
  summary: 'Met à jour une officine',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['officines'],
  request: {
    params: z.object({ id: z.uuid() }),
    body: {
      content: { 'application/json': { schema: UpdateOfficineInputSchema } },
    },
  },
  responses: {
    200: {
      description: 'Officine mise à jour',
      content: { 'application/json': { schema: OfficineSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/officines/{id}',
  summary: 'Supprime (soft-delete) une officine',
  description: 'Réservé au propriétaire (rôle owner).',
  tags: ['officines'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Supprimée' },
    401: errorResponse('Non authentifié'),
    403: errorResponse('Pas owner'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});
