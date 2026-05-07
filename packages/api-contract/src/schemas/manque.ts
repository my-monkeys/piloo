// Schémas Zod /api/v1/officines/:officineId/signaler-manque (#147).
//
// Contexte produit : un utilisateur (souvent un proche, role viewer
// ou editor) constate qu'il manque un médicament dans l'officine et
// veut alerter les responsables (owner / editors). On ne touche pas
// aux boîtes : on ne fait que générer une alerte `manque_signale`
// pour les personnes habilitées à reconstituer le stock.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const Cip13 = z.string().regex(/^\d{13}$/, 'cip13 doit faire 13 chiffres');

export const SignalerManqueInputSchema = z
  .object({
    cip13: Cip13.optional(),
    libelle: z.string().min(1).max(200).optional(),
    message: z.string().max(500).optional(),
  })
  .refine((data) => data.cip13 !== undefined || data.libelle !== undefined, {
    message: 'cip13 ou libelle requis',
  })
  .openapi('SignalerManqueInput');

export const SignalerManqueResponseSchema = z
  .object({
    alertes_creees: z.number().int().min(0),
  })
  .openapi('SignalerManqueResponse');

export type SignalerManqueInput = z.infer<typeof SignalerManqueInputSchema>;
export type SignalerManqueResponse = z.infer<typeof SignalerManqueResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('ManqueApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'post',
  path: '/v1/officines/{officineId}/signaler-manque',
  summary: 'Signale un manque de médicament dans une officine',
  description:
    "Tout membre (owner/editor/viewer) de l'officine peut signaler. " +
    'Crée une alerte `manque_signale` pour chaque owner/editor (le ' +
    'signaleur exclu).',
  tags: ['alertes'],
  request: {
    params: z.object({ officineId: z.uuid() }),
    body: { content: { 'application/json': { schema: SignalerManqueInputSchema } } },
  },
  responses: {
    201: {
      description: 'Manque signalé',
      content: { 'application/json': { schema: SignalerManqueResponseSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
    404: errorResponse('Officine introuvable ou non partagée'),
  },
});
