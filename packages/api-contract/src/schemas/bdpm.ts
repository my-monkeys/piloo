// Schémas Zod /api/v1/bdpm (#76).
//
// Ces endpoints sont publics (BDPM = donnée ouverte data.gouv.fr) et
// servent au mobile à décider s'il doit pull une nouvelle base.
//
//   GET /v1/bdpm/version            → version active + total
//   GET /v1/bdpm/diff?from=YYYY-MM-DD → médicaments changés/ajoutés
//
// Limite : la table miroir ne garde pas d'historique de delete →
// le diff couvre les ajouts et modifications, pas les retraits AMM.
// Le mobile fait un full reload (#78) tous les ~12 mois pour
// nettoyer les CIS retirés.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const Cip = z.string().regex(/^\d{7,13}$/);

export const BdpmMedicamentSchema = z
  .object({
    cis: z.string(),
    cip13: Cip.nullable(),
    cip7: Cip.nullable(),
    denomination: z.string(),
    forme: z.string().nullable(),
    dosage: z.string().nullable(),
    voie_administration: z.string().nullable(),
    titulaire: z.string().nullable(),
    statut_amm: z.string().nullable(),
    taux_remboursement: z.number().int().min(0).max(100).nullable(),
    version_bdpm: z.iso.date(),
  })
  .openapi('BdpmMedicament');

export const BdpmVersionResponseSchema = z
  .object({
    version: z.iso.date().nullable(),
    total_cis: z.number().int().min(0),
  })
  .openapi('BdpmVersionResponse');

export const BdpmDiffQuerySchema = z
  .object({
    from: z.iso.date(),
  })
  .openapi('BdpmDiffQuery');

export const BdpmDiffResponseSchema = z
  .object({
    from: z.iso.date(),
    current: z.iso.date().nullable(),
    items: z.array(BdpmMedicamentSchema),
  })
  .openapi('BdpmDiffResponse');

export type BdpmMedicament = z.infer<typeof BdpmMedicamentSchema>;
export type BdpmVersionResponse = z.infer<typeof BdpmVersionResponseSchema>;
export type BdpmDiffResponse = z.infer<typeof BdpmDiffResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('BdpmApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/bdpm/version',
  summary: 'Version BDPM active sur le serveur',
  description:
    "Retourne la `version` (date YYYY-MM-DD) la plus récente parmi les médicaments en base, ou `null` si la base n'a jamais été importée.",
  tags: ['bdpm'],
  responses: {
    200: {
      description: 'Version courante',
      content: { 'application/json': { schema: BdpmVersionResponseSchema } },
    },
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/bdpm/diff',
  summary: 'Médicaments ajoutés ou mis à jour depuis une date',
  description:
    'Retourne les lignes dont `version_bdpm > from`. Ne couvre PAS les CIS retirés de la BDPM (cf. limite documentée).',
  tags: ['bdpm'],
  request: { query: BdpmDiffQuerySchema },
  responses: {
    200: {
      description: 'Diff',
      content: { 'application/json': { schema: BdpmDiffResponseSchema } },
    },
    400: errorResponse('Paramètre `from` invalide'),
  },
});
