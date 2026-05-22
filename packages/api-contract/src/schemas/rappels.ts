// Schémas Zod du contrat /api/v1/.../rappels (#98).
// Rappels rapides sur un médicament, sans dépendance ordonnance.
// Cf. docs/data-model.md §"rappels".
import { z } from 'zod';

import { registry } from '../openapi.ts';

const Cip13 = z.string().regex(/^\d{13}$/, 'cip13 doit faire 13 chiffres');
/// 0 est volontairement INTERDIT : on utilise `null` pour signifier
/// "pas de prise à ce moment-là". 0 voudrait dire "0 comprimé prescrit"
/// — incohérent.
const QuantiteMoment = z.number().int().min(1).max(99).nullable();

export const RappelSchema = z
  .object({
    id: z.uuid(),
    officine_id: z.uuid(),
    cip13: Cip13,
    nom_texte: z.string().min(1).max(255),
    unite: z.string().min(1).max(32),
    quantite_matin: QuantiteMoment,
    quantite_midi: QuantiteMoment,
    quantite_soir: QuantiteMoment,
    quantite_coucher: QuantiteMoment,
    date_debut: z.iso.date(),
    date_fin: z.iso.date().nullable(),
    actif: z.boolean(),
    notes: z.string().max(2000).nullable(),
    cree_par_user_id: z.uuid(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    deleted_at: z.iso.datetime().nullable(),
  })
  .openapi('Rappel');

// Au moins UN moment doit être renseigné — un rappel sans aucun horaire
// n'a aucun sens. La validation `.refine` retourne 400 avec un message
// clair côté client.
const atLeastOneMoment = (data: {
  quantite_matin: number | null;
  quantite_midi: number | null;
  quantite_soir: number | null;
  quantite_coucher: number | null;
}): boolean =>
  data.quantite_matin !== null ||
  data.quantite_midi !== null ||
  data.quantite_soir !== null ||
  data.quantite_coucher !== null;

export const CreateRappelInputSchema = z
  .object({
    cip13: Cip13,
    nom_texte: z.string().min(1).max(255),
    unite: z.string().min(1).max(32).optional(),
    quantite_matin: QuantiteMoment.optional(),
    quantite_midi: QuantiteMoment.optional(),
    quantite_soir: QuantiteMoment.optional(),
    quantite_coucher: QuantiteMoment.optional(),
    date_debut: z.iso.date(),
    date_fin: z.iso.date().nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
  })
  .refine(
    (d) =>
      atLeastOneMoment({
        quantite_matin: d.quantite_matin ?? null,
        quantite_midi: d.quantite_midi ?? null,
        quantite_soir: d.quantite_soir ?? null,
        quantite_coucher: d.quantite_coucher ?? null,
      }),
    { message: 'Au moins un moment (matin/midi/soir/coucher) doit avoir une quantité.' },
  )
  .openapi('CreateRappelInput');

export const UpdateRappelInputSchema = z
  .object({
    nom_texte: z.string().min(1).max(255).optional(),
    unite: z.string().min(1).max(32).optional(),
    quantite_matin: QuantiteMoment.optional(),
    quantite_midi: QuantiteMoment.optional(),
    quantite_soir: QuantiteMoment.optional(),
    quantite_coucher: QuantiteMoment.optional(),
    date_debut: z.iso.date().optional(),
    date_fin: z.iso.date().nullable().optional(),
    actif: z.boolean().optional(),
    notes: z.string().max(2000).nullable().optional(),
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
  .openapi('RappelApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/officines/{officineId}/rappels',
  summary: "Liste les rappels d'une officine",
  description: 'Renvoie les rappels non soft-deleted, triés par création décroissante.',
  tags: ['rappels'],
  request: { params: z.object({ officineId: z.uuid() }) },
  responses: {
    200: {
      description: 'Liste',
      content: { 'application/json': { schema: ListRappelsResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès à l'officine"),
    404: errorResponse('Officine introuvable'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/officines/{officineId}/rappels',
  summary: 'Crée un rappel rapide dans une officine',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['rappels'],
  request: {
    params: z.object({ officineId: z.uuid() }),
    body: { content: { 'application/json': { schema: CreateRappelInputSchema } } },
  },
  responses: {
    201: {
      description: 'Rappel créé',
      content: { 'application/json': { schema: RappelSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Officine introuvable'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/rappels/{id}',
  summary: "Détail d'un rappel",
  tags: ['rappels'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    200: { description: 'Détail', content: { 'application/json': { schema: RappelSchema } } },
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès"),
    404: errorResponse('Inconnu ou inaccessible'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/rappels/{id}',
  summary: 'Met à jour un rappel (quantités, dates, statut actif)',
  description: "Réservé aux rôles owner et editor sur l'officine du rappel.",
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
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnu ou inaccessible'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/rappels/{id}',
  summary: 'Supprime (soft-delete) un rappel',
  description: "Réservé aux rôles owner et editor sur l'officine du rappel.",
  tags: ['rappels'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Supprimé' },
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnu ou inaccessible'),
  },
});
