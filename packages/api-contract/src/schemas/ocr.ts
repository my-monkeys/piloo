// Schémas /api/v1/ocr/ordonnance (#152).
//
// L'endpoint reçoit une image (base64) et retourne une structure
// parsée par Gemini vision. AUCUNE création serveur — l'utilisateur
// valide ligne par ligne dans l'app et appelle ensuite POST
// /v1/officines/{id}/ordonnances pour persister.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const MAX_IMAGE_B64 = 8 * 1024 * 1024; // ~8 MB après décode base64 = ~5.3 MB raw.

export const OcrOrdonnanceInputSchema = z
  .object({
    image_base64: z
      .string()
      .min(1)
      .max(MAX_IMAGE_B64, 'Image trop volumineuse (limite 8 Mo base64)'),
    mime_type: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  })
  .openapi('OcrOrdonnanceInput');

export const OcrPrescriptionSchema = z
  .object({
    nom_texte: z.string(),
    unites_par_prise: z.number().nullable(),
    unite: z.string().nullable(),
    frequence: z.string().nullable(),
    duree_jours: z.number().int().nullable(),
    indication: z.string().nullable(),
  })
  .openapi('OcrPrescription');

export const OcrOrdonnanceResponseSchema = z
  .object({
    prescripteur: z.string().nullable(),
    specialite: z.string().nullable(),
    date_prescription: z.iso.date().nullable(),
    notes: z.string().nullable(),
    prescriptions: z.array(OcrPrescriptionSchema),
  })
  .openapi('OcrOrdonnanceResponse');

export type OcrOrdonnanceInput = z.infer<typeof OcrOrdonnanceInputSchema>;
export type OcrPrescription = z.infer<typeof OcrPrescriptionSchema>;
export type OcrOrdonnanceResponse = z.infer<typeof OcrOrdonnanceResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('OcrApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'post',
  path: '/v1/ocr/ordonnance',
  summary: "Extrait le contenu d'une photo d'ordonnance via vision LLM",
  description:
    'Reçoit une image base64 et retourne les prescripteur/date/médicaments parsés. ' +
    "L'utilisateur valide ensuite ligne par ligne avant POST officines/.../ordonnances. " +
    'Aucune persistance serveur (RGPD : image possiblement nominative).',
  tags: ['ocr'],
  request: {
    body: { content: { 'application/json': { schema: OcrOrdonnanceInputSchema } } },
  },
  responses: {
    200: {
      description: 'Structure extraite',
      content: { 'application/json': { schema: OcrOrdonnanceResponseSchema } },
    },
    400: errorResponse('Body invalide ou image illisible'),
    401: errorResponse('Non authentifié'),
    422: errorResponse('Aucun contenu extractible (photo floue / non médicale)'),
  },
});
