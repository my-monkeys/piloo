// Schémas Zod /api/v1/me (#162). Profil utilisateur — droit de
// rectification RGPD (article 16).
import { z } from 'zod';

import { registry } from '../openapi.ts';

const TypeCompteEnum = z.enum(['particulier', 'pro']);

export const GetMeResponseSchema = z
  .object({
    id: z.uuid(),
    email: z.email(),
    nom: z.string(),
    prenom: z.string(),
    name: z.string(),
    telephone: z.string().nullable(),
    type_compte: TypeCompteEnum,
    image: z.string().nullable(),
    deleted_at: z.iso.datetime().nullable(),
    created_at: z.iso.datetime(),
  })
  .openapi('GetMeResponse');

export const UpdateMeInputSchema = z
  .object({
    nom: z.string().min(1).max(255).optional(),
    prenom: z.string().min(1).max(255).optional(),
    name: z.string().min(1).max(255).optional(),
    telephone: z.string().max(32).nullable().optional(),
    image: z.url().max(2048).nullable().optional(),
  })
  .openapi('UpdateMeInput');

export type GetMeResponse = z.infer<typeof GetMeResponseSchema>;
export type UpdateMeInput = z.infer<typeof UpdateMeInputSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('MeApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/me',
  summary: "Profil de l'utilisateur courant",
  description: 'Renvoie le profil complet — email, identité, type de compte.',
  tags: ['me'],
  responses: {
    200: {
      description: 'Profil',
      content: { 'application/json': { schema: GetMeResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
    404: errorResponse('Introuvable'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/me',
  summary: 'Modifie le profil (droit de rectification RGPD article 16)',
  description:
    "Met à jour nom, prenom, telephone, image. L'email passe par le flow Better Auth dédié (vérification email).",
  tags: ['me'],
  request: {
    body: { content: { 'application/json': { schema: UpdateMeInputSchema } } },
  },
  responses: {
    200: {
      description: 'Profil mis à jour',
      content: { 'application/json': { schema: GetMeResponseSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    404: errorResponse('Introuvable'),
  },
});
