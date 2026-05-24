// Schémas Zod /api/v1/officines/{id}/partages (#339).
//
// Gestion des membres d'une officine :
//   GET    /v1/officines/{officineId}/partages           → liste membres + invitations pending
//   PATCH  /v1/officines/{officineId}/partages/{userId}  → change le rôle d'un membre (owner only)
//   DELETE /v1/officines/{officineId}/partages/{userId}  → soft-delete (revoke ou self-leave)
//
// Les invitations elles-mêmes restent gérées par invitations.ts.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const RoleEnum = z.enum(['owner', 'editor', 'viewer']);

/// Un membre actif (acceptedAt != null, deletedAt == null) tel
/// qu'affiché dans l'écran "Membres" mobile/web.
export const PartageMemberSchema = z
  .object({
    user_id: z.uuid(),
    email: z.string(),
    display_name: z.string(),
    role: RoleEnum,
    invited_at: z.iso.datetime(),
    accepted_at: z.iso.datetime(),
  })
  .openapi('PartageMember');

/// Une invitation pending pour l'officine (acceptedAt null, expiresAt
/// futur). Affichée à part des membres actifs dans l'UI — l'user n'a
/// pas encore rejoint, on ne peut pas la révoquer comme un membre.
export const PendingMemberInvitationSchema = z
  .object({
    invitation_id: z.uuid(),
    email: z.string().nullable(),
    role: RoleEnum,
    expires_at: z.iso.datetime(),
    created_at: z.iso.datetime(),
  })
  .openapi('PendingMemberInvitation');

export const PartagesListSchema = z
  .object({
    members: z.array(PartageMemberSchema),
    pending_invitations: z.array(PendingMemberInvitationSchema),
  })
  .openapi('PartagesList');

export const UpdatePartageRoleInputSchema = z
  .object({
    role: RoleEnum,
  })
  .openapi('UpdatePartageRoleInput');

export type PartageMember = z.infer<typeof PartageMemberSchema>;
export type PendingMemberInvitation = z.infer<typeof PendingMemberInvitationSchema>;
export type PartagesList = z.infer<typeof PartagesListSchema>;
export type UpdatePartageRoleInput = z.infer<typeof UpdatePartageRoleInputSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('PartagesApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/officines/{officineId}/partages',
  summary: "Liste les membres + invitations en attente d'une officine",
  description:
    'Lecture autorisée aux 3 rôles (owner / editor / viewer). Retourne deux listes séparées : membres actifs et invitations encore valides.',
  tags: ['partages'],
  request: { params: z.object({ officineId: z.uuid() }) },
  responses: {
    200: {
      description: 'Liste membres + invitations',
      content: { 'application/json': { schema: PartagesListSchema } },
    },
    401: errorResponse('Non authentifié'),
    403: errorResponse('Non membre de cette officine'),
    404: errorResponse('Officine inconnue'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/officines/{officineId}/partages/{userId}',
  summary: "Change le rôle d'un membre",
  description:
    'Owner uniquement. Refuse si la modification rétrograderait le dernier owner (au moins 1 owner actif requis par officine).',
  tags: ['partages'],
  request: {
    params: z.object({ officineId: z.uuid(), userId: z.uuid() }),
    body: { content: { 'application/json': { schema: UpdatePartageRoleInputSchema } } },
  },
  responses: {
    200: {
      description: 'Membre mis à jour',
      content: { 'application/json': { schema: PartageMemberSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Pas owner'),
    404: errorResponse('Membre introuvable'),
    409: errorResponse('Dernier owner : rétrogradation refusée'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/officines/{officineId}/partages/{userId}',
  summary: 'Révoque un membre (ou self-leave)',
  description:
    "Owner uniquement pour révoquer un autre, OU n'importe quel membre pour se retirer lui-même. Refuse si c'est le dernier owner.",
  tags: ['partages'],
  request: { params: z.object({ officineId: z.uuid(), userId: z.uuid() }) },
  responses: {
    204: { description: 'Membre révoqué' },
    401: errorResponse('Non authentifié'),
    403: errorResponse('Pas autorisé'),
    404: errorResponse('Membre introuvable'),
    409: errorResponse('Dernier owner : suppression refusée'),
  },
});
