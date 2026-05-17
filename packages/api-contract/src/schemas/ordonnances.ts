// Schémas Zod du contrat /api/v1/.../ordonnances + prescriptions (#106).
// Cf. docs/api-contract.md §"Ordonnances" + docs/data-model.md §"ordonnances".
//
// Une ordonnance = en-tête (prescripteur, date, source) + N prescriptions
// (médicament + posologie). À la création on accepte d'imbriquer les
// prescriptions pour économiser un round-trip — au-delà du POST initial,
// les prescriptions ont leurs propres endpoints.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const Cip13 = z.string().regex(/^\d{13}$/, 'cip13 doit faire 13 chiffres');
const SourceOrdonnanceEnum = z.enum(['manuelle', 'ocr']);
const FrequenceEnum = z.enum(['quotidien', 'hebdomadaire', 'a_la_demande']);
const MomentEnum = z.enum(['matin', 'midi', 'soir', 'coucher']);
const HoraireRegex = /^([01]\d|2[0-3]):[0-5]\d$/;

export const PosologieSchema = z
  .object({
    unitesParPrise: z.number().positive(),
    unite: z.string().min(1).max(32),
    frequence: FrequenceEnum,
    moments: z.array(MomentEnum).max(4).optional(),
    horaires: z.array(z.string().regex(HoraireRegex)).max(8).optional(),
    avecRepas: z.boolean().optional(),
    espacementMinutes: z
      .number()
      .int()
      .positive()
      .max(24 * 60)
      .nullable()
      .optional(),
  })
  .openapi('Posologie');

export const PrescriptionSchema = z
  .object({
    id: z.uuid(),
    ordonnance_id: z.uuid(),
    cip13: Cip13.nullable(),
    cis: z.string().max(16).nullable(),
    nom_texte: z.string().min(1).max(255),
    posologie: PosologieSchema,
    duree_jours: z.number().int().positive().max(3650).nullable(),
    indication: z.string().max(255).nullable(),
    notes: z.string().max(2000).nullable(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    deleted_at: z.iso.datetime().nullable(),
  })
  .openapi('Prescription');

export const CreatePrescriptionInputSchema = z
  .object({
    cip13: Cip13.nullable().optional(),
    cis: z.string().max(16).nullable().optional(),
    nom_texte: z.string().min(1).max(255),
    posologie: PosologieSchema,
    duree_jours: z.number().int().positive().max(3650).nullable().optional(),
    indication: z.string().max(255).nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
  })
  .openapi('CreatePrescriptionInput');

export const UpdatePrescriptionInputSchema = z
  .object({
    cip13: Cip13.nullable().optional(),
    cis: z.string().max(16).nullable().optional(),
    nom_texte: z.string().min(1).max(255).optional(),
    posologie: PosologieSchema.optional(),
    duree_jours: z.number().int().positive().max(3650).nullable().optional(),
    indication: z.string().max(255).nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
  })
  .openapi('UpdatePrescriptionInput');

export const OrdonnanceSchema = z
  .object({
    id: z.uuid(),
    officine_id: z.uuid(),
    prescripteur: z.string().max(255).nullable(),
    date_prescription: z.iso.date(),
    source: SourceOrdonnanceEnum,
    photo_url: z.url().max(2048).nullable(),
    notes: z.string().max(2000).nullable(),
    saisie_par: z.uuid(),
    created_at: z.iso.datetime(),
    updated_at: z.iso.datetime(),
    deleted_at: z.iso.datetime().nullable(),
  })
  .openapi('Ordonnance');

export const OrdonnanceWithPrescriptionsSchema = OrdonnanceSchema.extend({
  prescriptions: z.array(PrescriptionSchema),
}).openapi('OrdonnanceWithPrescriptions');

export const CreateOrdonnanceInputSchema = z
  .object({
    prescripteur: z.string().max(255).nullable().optional(),
    date_prescription: z.iso.date(),
    source: SourceOrdonnanceEnum.optional(),
    photo_url: z.url().max(2048).nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
    prescriptions: z.array(CreatePrescriptionInputSchema).max(50).optional(),
  })
  .openapi('CreateOrdonnanceInput');

export const UpdateOrdonnanceInputSchema = z
  .object({
    prescripteur: z.string().max(255).nullable().optional(),
    date_prescription: z.iso.date().optional(),
    photo_url: z.url().max(2048).nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
  })
  .openapi('UpdateOrdonnanceInput');

export const ListOrdonnancesResponseSchema = z
  .object({
    items: z.array(OrdonnanceSchema),
  })
  .openapi('ListOrdonnancesResponse');

export type Posologie = z.infer<typeof PosologieSchema>;
export type Prescription = z.infer<typeof PrescriptionSchema>;
export type CreatePrescriptionInput = z.infer<typeof CreatePrescriptionInputSchema>;
export type UpdatePrescriptionInput = z.infer<typeof UpdatePrescriptionInputSchema>;
export type Ordonnance = z.infer<typeof OrdonnanceSchema>;
export type OrdonnanceWithPrescriptions = z.infer<typeof OrdonnanceWithPrescriptionsSchema>;
export type CreateOrdonnanceInput = z.infer<typeof CreateOrdonnanceInputSchema>;
export type UpdateOrdonnanceInput = z.infer<typeof UpdateOrdonnanceInputSchema>;
export type ListOrdonnancesResponse = z.infer<typeof ListOrdonnancesResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('OrdonnanceApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/officines/{officineId}/ordonnances',
  summary: "Liste les ordonnances d'une officine",
  description:
    'Renvoie les ordonnances non soft-deleted, triées par date_prescription décroissante.',
  tags: ['ordonnances'],
  request: { params: z.object({ officineId: z.uuid() }) },
  responses: {
    200: {
      description: 'Liste',
      content: { 'application/json': { schema: ListOrdonnancesResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès à l'officine"),
    404: errorResponse('Officine introuvable'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/officines/{officineId}/ordonnances',
  summary: 'Crée une ordonnance (avec prescriptions imbriquées optionnelles)',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['ordonnances'],
  request: {
    params: z.object({ officineId: z.uuid() }),
    body: { content: { 'application/json': { schema: CreateOrdonnanceInputSchema } } },
  },
  responses: {
    201: {
      description: 'Ordonnance créée (avec prescriptions)',
      content: { 'application/json': { schema: OrdonnanceWithPrescriptionsSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Officine introuvable'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/ordonnances/{id}',
  summary: "Détail d'une ordonnance (prescriptions imbriquées)",
  tags: ['ordonnances'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    200: {
      description: 'Détail',
      content: { 'application/json': { schema: OrdonnanceWithPrescriptionsSchema } },
    },
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès"),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/ordonnances/{id}',
  summary: "Met à jour l'en-tête d'une ordonnance",
  description: 'Réservé aux rôles owner et editor.',
  tags: ['ordonnances'],
  request: {
    params: z.object({ id: z.uuid() }),
    body: { content: { 'application/json': { schema: UpdateOrdonnanceInputSchema } } },
  },
  responses: {
    200: {
      description: 'Ordonnance mise à jour',
      content: { 'application/json': { schema: OrdonnanceSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/ordonnances/{id}',
  summary: 'Soft-delete une ordonnance (cascade vers prescriptions)',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['ordonnances'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Supprimée' },
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/ordonnances/{id}/prescriptions',
  summary: 'Ajoute une prescription à une ordonnance existante',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['ordonnances'],
  request: {
    params: z.object({ id: z.uuid() }),
    body: { content: { 'application/json': { schema: CreatePrescriptionInputSchema } } },
  },
  responses: {
    201: {
      description: 'Prescription créée',
      content: { 'application/json': { schema: PrescriptionSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Ordonnance introuvable'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/prescriptions/{id}',
  summary: 'Met à jour une prescription',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['ordonnances'],
  request: {
    params: z.object({ id: z.uuid() }),
    body: { content: { 'application/json': { schema: UpdatePrescriptionInputSchema } } },
  },
  responses: {
    200: {
      description: 'Prescription mise à jour',
      content: { 'application/json': { schema: PrescriptionSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/prescriptions/{id}',
  summary: 'Soft-delete une prescription',
  description: 'Réservé aux rôles owner et editor.',
  tags: ['ordonnances'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Supprimée' },
    401: errorResponse('Non authentifié'),
    403: errorResponse('Rôle insuffisant'),
    404: errorResponse('Inconnue ou inaccessible'),
  },
});
