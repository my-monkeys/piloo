// Schémas Zod /api/v1 invitations partage officine (#123/#125).
//
// Flow :
//   POST /v1/officines/{officineId}/invitations  → crée + retourne le token
//   GET  /v1/invitations/{token}                  → preview avant accept (public)
//   POST /v1/invitations/{token}/accept           → auth requis, crée partage
import { z } from 'zod';

import { registry } from '../openapi.ts';

const RoleEnum = z.enum(['owner', 'editor', 'viewer']);

export const InvitationSchema = z
  .object({
    id: z.uuid(),
    officine_id: z.uuid(),
    role: RoleEnum,
    invited_by_user_id: z.uuid(),
    email: z.string().nullable(),
    expires_at: z.iso.datetime(),
    accepted_at: z.iso.datetime().nullable(),
    accepted_by_user_id: z.uuid().nullable(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    deleted_at: z.iso.datetime().nullable(),
  })
  .openapi('Invitation');

export const CreateInvitationInputSchema = z
  .object({
    role: RoleEnum,
    /** Optionnel — affiché à l'invité côté preview. */
    email: z.email().max(255).nullable().optional(),
    /** TTL en heures, par défaut 72 (3 jours). Max 168 (1 semaine). */
    ttlHours: z.number().int().min(1).max(168).optional(),
  })
  .openapi('CreateInvitationInput');

/// Vue publique d'une invitation — pas d'IDs internes ni d'email
/// inviteur (PII), juste de quoi afficher le preview avant accept.
export const InvitationPreviewSchema = z
  .object({
    officine_nom: z.string(),
    role: RoleEnum,
    invited_by_name: z.string(),
    expires_at: z.iso.datetime(),
    /** Indique si l'invitation est encore acceptable. */
    status: z.enum(['pending', 'expired', 'accepted', 'revoked']),
  })
  .openapi('InvitationPreview');

export const AcceptInvitationResponseSchema = z
  .object({
    officine_id: z.uuid(),
    role: RoleEnum,
  })
  .openapi('AcceptInvitationResponse');

export type Invitation = z.infer<typeof InvitationSchema>;
export type CreateInvitationInput = z.infer<typeof CreateInvitationInputSchema>;
export type InvitationPreview = z.infer<typeof InvitationPreviewSchema>;
export type AcceptInvitationResponse = z.infer<typeof AcceptInvitationResponseSchema>;

/// Élément de la liste retournée par GET /v1/me/invitations (#129).
/// Inclut le token (= id) pour autoriser un accept inline depuis la
/// liste des officines, sans roundtrip preview.
export const PendingInvitationSchema = z
  .object({
    token: z.uuid(),
    officine_id: z.uuid(),
    officine_nom: z.string(),
    role: RoleEnum,
    invited_by_name: z.string(),
    expires_at: z.iso.datetime(),
  })
  .openapi('PendingInvitation');

export const PendingInvitationsListSchema = z
  .object({
    items: z.array(PendingInvitationSchema),
  })
  .openapi('PendingInvitationsList');

export type PendingInvitation = z.infer<typeof PendingInvitationSchema>;
export type PendingInvitationsList = z.infer<typeof PendingInvitationsListSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('InvitationApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'post',
  path: '/v1/officines/{officineId}/invitations',
  summary: 'Crée une invitation à rejoindre une officine',
  description: 'Owner uniquement. Génère un token (UUID v4) inclus dans le lien partageable.',
  tags: ['invitations'],
  request: {
    params: z.object({ officineId: z.uuid() }),
    body: { content: { 'application/json': { schema: CreateInvitationInputSchema } } },
  },
  responses: {
    201: {
      description: 'Invitation créée',
      content: { 'application/json': { schema: InvitationSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Pas owner'),
    404: errorResponse('Officine inconnue'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/invitations/{token}',
  summary: "Aperçu public d'une invitation",
  description: "Public (pas d'auth) — sert au preview côté lien partagé avant signup/login.",
  tags: ['invitations'],
  request: { params: z.object({ token: z.uuid() }) },
  responses: {
    200: {
      description: 'Preview',
      content: { 'application/json': { schema: InvitationPreviewSchema } },
    },
    404: errorResponse('Token inconnu'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/me/invitations',
  summary: "Liste les invitations en attente adressées à l'utilisateur courant",
  description:
    'Filtre par email de l\'user authentifié + statut pending (acceptedAt null, deletedAt null, expiresAt > now). Utilisé pour le badge "Invitation en attente" de l\'écran Mes officines (#129).',
  tags: ['invitations'],
  responses: {
    200: {
      description: 'Liste',
      content: { 'application/json': { schema: PendingInvitationsListSchema } },
    },
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/invitations/{token}/accept',
  summary: "Accepte une invitation et rejoint l'officine",
  description:
    "Requiert l'auth (l'utilisateur qui accepte). Crée la ligne `partages` et marque l'invitation acceptée.",
  tags: ['invitations'],
  request: { params: z.object({ token: z.uuid() }) },
  responses: {
    200: {
      description: 'Accepté',
      content: { 'application/json': { schema: AcceptInvitationResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
    404: errorResponse('Token inconnu'),
    409: errorResponse('Déjà accepté ou expiré'),
  },
});
