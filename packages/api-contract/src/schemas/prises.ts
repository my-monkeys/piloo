// Schémas Zod du contrat /api/v1/prises (#114).
//
// Endpoint timeline : récupère les prises planifiées pour un jour donné
// (statut + lien prescription inline) afin d'afficher l'écran "Aujourd'hui"
// du mobile (#14) sans roundtrip supplémentaire.
//
// Convention : l'`officine_id` est *obligatoire* — un user a souvent accès
// à plusieurs officines (perso + patients pro), on ne mélange pas leurs
// timelines. Le client choisit explicitement laquelle.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const StatutPriseEnum = z.enum(['prevue', 'prise', 'sautee', 'oubliee']);

// Posologie en JSON ouvert : le format évolue produit (cf. schema Drizzle
// `prescriptions.posologie`). On expose tel quel — le mobile la rend
// avec ses propres règles d'affichage.
const PosologieSchema = z.record(z.string(), z.unknown()).openapi('Posologie');

// Sous-objet prescription dénormalisé dans chaque prise — évite un
// /v1/prescriptions/:id par item dans la timeline. Pour une prise
// issue d'un rappel rapide (#343), on remplit cet objet avec les
// données du rappel (id = rappel.id, ordonnance_id = rappel.id,
// posologie synthétique). Côté mobile, l'affichage reste uniforme.
const PriseTimelinePrescriptionSchema = z
  .object({
    id: z.uuid(),
    ordonnance_id: z.uuid(),
    nom_texte: z.string(),
    cip13: z.string().nullable(),
    indication: z.string().nullable(),
    posologie: PosologieSchema,
  })
  .openapi('PriseTimelinePrescription');

export const PriseTimelineItemSchema = z
  .object({
    id: z.uuid(),
    officine_id: z.uuid(),
    datetime_prevue: z.iso.datetime(),
    datetime_validation: z.iso.datetime().nullable(),
    statut: StatutPriseEnum,
    notes: z.string().nullable(),
    prescription: PriseTimelinePrescriptionSchema,
  })
  .openapi('PriseTimelineItem');

export const ListPrisesResponseSchema = z
  .object({
    // Date résolue côté serveur (utile quand le client demande "today" et
    // veut afficher la date dans l'UI sans recalcul fuseau).
    date: z.iso.date(),
    items: z.array(PriseTimelineItemSchema),
  })
  .openapi('ListPrisesResponse');

// Validation manuelle (Prise/Sautée/Reset prevue). `oubliee` n'est PAS
// settable manuellement — c'est l'état terminal posé par le cron #118
// quand on dépasse +1h sans action ; le repasser à `prevue` revient à
// "j'oublie d'avoir oublié", ce qu'on ne veut pas tracer.
//
// `datetime_prevue` (#120) : permet le tap-long sur une card prise pour
// déplacer ponctuellement l'horaire (ex: "je prends mon ramipril à 20h
// plutôt qu'à 19h aujourd'hui"). N'altère pas la posologie de l'ordo
// — uniquement l'occurrence concernée.
export const UpdatePriseInputSchema = z
  .object({
    statut: z.enum(['prevue', 'prise', 'sautee']).optional(),
    notes: z.string().max(2000).nullable().optional(),
    datetime_prevue: z.iso.datetime().optional(),
  })
  .refine(
    (v) => v.statut !== undefined || v.notes !== undefined || v.datetime_prevue !== undefined,
    { message: 'Au moins un champ doit être fourni.' },
  )
  .openapi('UpdatePriseInput');

export type PriseTimelineItem = z.infer<typeof PriseTimelineItemSchema>;
export type ListPrisesResponse = z.infer<typeof ListPrisesResponseSchema>;
export type UpdatePriseInput = z.infer<typeof UpdatePriseInputSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('PrisesApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/prises/today',
  summary: "Prises planifiées pour aujourd'hui (timeline)",
  description:
    "Renvoie les prises de l'officine demandée pour la date courante (fuseau serveur). " +
    'Le statut + la prescription jointe sont inclus pour rendre la timeline sans roundtrip.',
  tags: ['prises'],
  request: {
    query: z.object({
      officine_id: z.uuid(),
    }),
  },
  responses: {
    200: {
      description: 'Liste des prises du jour',
      content: { 'application/json': { schema: ListPrisesResponseSchema } },
    },
    400: errorResponse('Query invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès à cette officine"),
    404: errorResponse('Officine inconnue'),
  },
});

registry.registerPath({
  method: 'patch',
  path: '/v1/prises/{id}',
  summary: 'Valider, sauter ou réinitialiser une prise planifiée',
  description:
    'Marque la prise `prise` (avec horodatage de validation), `sautee` (idem), ou la repasse à `prevue` (datetime_validation remis à null). ' +
    "Pas de transition vers `oubliee` manuelle — c'est l'état terminal posé par le cron.",
  tags: ['prises'],
  request: {
    params: z.object({ id: z.uuid() }),
    body: {
      content: { 'application/json': { schema: UpdatePriseInputSchema } },
    },
  },
  responses: {
    200: {
      description: 'Prise mise à jour',
      content: { 'application/json': { schema: PriseTimelineItemSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    403: errorResponse('Pas le droit (lecteur)'),
    404: errorResponse('Prise inconnue'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/prises',
  summary: 'Prises planifiées pour une date précise',
  description:
    'Variante de /v1/prises/today qui prend une date explicite (YYYY-MM-DD). ' +
    'Utilisé par le navigateur de calendrier du mobile.',
  tags: ['prises'],
  request: {
    query: z.object({
      officine_id: z.uuid(),
      date: z.iso.date(),
    }),
  },
  responses: {
    200: {
      description: 'Liste des prises de la date',
      content: { 'application/json': { schema: ListPrisesResponseSchema } },
    },
    400: errorResponse('Query invalide (date manquante / mal formée)'),
    401: errorResponse('Non authentifié'),
    403: errorResponse("Pas d'accès à cette officine"),
    404: errorResponse('Officine inconnue'),
  },
});
