// Schémas Zod /api/v1/bdpm (#76).
//
// Ces endpoints sont publics (BDPM = donnée ouverte data.gouv.fr) et
// servent au mobile à décider s'il doit pull une nouvelle base.
//
//   GET /v1/bdpm/version            → version active + total
//   GET /v1/bdpm/diff?from=YYYY-MM-DD → médicaments changés/ajoutés
//   GET /v1/bdpm/search?q=...       → recherche par nom ou CIP (web manual entry)
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
    /// Résumé IA pré-généré (#167). Null tant que la pipeline LLM
    /// n'a pas encore traité ce CIP — l'UI affiche un placeholder.
    ai_summary: z.string().nullable().optional(),
    version_bdpm: z.iso.date(),
    /// Libellé brut BDPM de la présentation (debug + fallback affichage).
    libelle_presentation: z.string().nullable().optional(),
    /// Contenant user-friendly : "boîte", "flacon", "tube"…
    container: z.string().nullable().optional(),
    /// Nb total de doses dans le conditionnement (auto-fill mobile).
    total_doses: z.number().int().positive().nullable().optional(),
    /// Unité de dose singulier ("comprimé", "ml", "g"…).
    dose_unit: z.string().nullable().optional(),
    /// Pluriel ("comprimés", "ml", "g"…) — fourni explicitement pour
    /// éviter une lib de pluralisation côté mobile.
    dose_unit_plural: z.string().nullable().optional(),
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

// /search : aide à la saisie manuelle d'une boîte côté web (et plus tard
// mobile). q ≥ 2 caractères. Si q matche un CIP (7 ou 13 chiffres) on cherche
// d'abord par CIP, sinon fuzzy sur denomination.
export const BdpmSearchQuerySchema = z
  .object({
    q: z.string().trim().min(2).max(120),
  })
  .openapi('BdpmSearchQuery');

export const BdpmSearchResponseSchema = z
  .object({
    items: z.array(BdpmMedicamentSchema),
  })
  .openapi('BdpmSearchResponse');

// /resolve : résolution batch CIP13 → médicament, pour afficher les NOMS sur
// une liste d'inventaire côté web (le type Boite ne stocke que le cip13).
// `cips` = liste de CIP séparés par des virgules (ex. "3400939038537,3400936073005").
export const BdpmResolveQuerySchema = z
  .object({
    cips: z.string().trim().min(1).max(8000),
  })
  .openapi('BdpmResolveQuery');

export const BdpmResolveResponseSchema = z
  .object({
    items: z.array(BdpmMedicamentSchema),
  })
  .openapi('BdpmResolveResponse');

export type BdpmMedicament = z.infer<typeof BdpmMedicamentSchema>;
export type BdpmVersionResponse = z.infer<typeof BdpmVersionResponseSchema>;
export type BdpmDiffResponse = z.infer<typeof BdpmDiffResponseSchema>;
export type BdpmSearchQuery = z.infer<typeof BdpmSearchQuerySchema>;
export type BdpmSearchResponse = z.infer<typeof BdpmSearchResponseSchema>;
export type BdpmResolveQuery = z.infer<typeof BdpmResolveQuerySchema>;
export type BdpmResolveResponse = z.infer<typeof BdpmResolveResponseSchema>;

/// Sections de la notice RCP scrapées sur la base ANSM publique.
/// L'app les affiche tels quels (relais d'information publique, sans
/// transformation — hors scope MDR cf. positionnement non-dispositif-médical).
export const BdpmNoticeSectionSchema = z
  .object({
    number: z.string(),
    title: z.string(),
    text: z.string(),
  })
  .openapi('BdpmNoticeSection');

export const BdpmNoticeResponseSchema = z
  .object({
    cis: z.string(),
    source_url: z.url(),
    scraped_at: z.iso.datetime(),
    sections: z.array(BdpmNoticeSectionSchema),
  })
  .openapi('BdpmNoticeResponse');

export type BdpmNoticeSection = z.infer<typeof BdpmNoticeSectionSchema>;
export type BdpmNoticeResponse = z.infer<typeof BdpmNoticeResponseSchema>;

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

registry.registerPath({
  method: 'get',
  path: '/v1/bdpm/sqlite',
  summary: 'Télécharge le fichier SQLite BDPM mobile (gzippé)',
  description:
    'Sert le fichier SQLite généré depuis Postgres, gzippé. Le mobile envoie `?version=YYYY-MM-DD` pour skip le download si la version locale est à jour (réponse 304). En-tête `X-Piloo-Bdpm-Version` indique la version courante.',
  tags: ['bdpm'],
  responses: {
    200: {
      description: 'SQLite gzippé',
      content: {
        'application/x-sqlite3': {
          schema: { type: 'string', format: 'binary' },
        },
      },
    },
    304: {
      description: 'Version inchangée, pas de re-download nécessaire',
    },
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/bdpm/{cis}/notice',
  summary: 'Sections du RCP (notice) scrapées sur la base ANSM publique',
  description:
    "Scrape la page http://base-donnees-publique.medicaments.gouv.fr/medicament/{cis}/extrait et retourne les sections 4.1 à 4.9 du RCP (indications, posologie, contre-indications, effets indésirables, etc.). Contenu relayé tel quel — Piloo n'altère pas le texte ANSM pour rester hors MDR.",
  tags: ['bdpm'],
  request: { params: z.object({ cis: z.string().min(1) }) },
  responses: {
    200: {
      description: 'Notice scrapée',
      content: { 'application/json': { schema: BdpmNoticeResponseSchema } },
    },
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/bdpm/search',
  summary: 'Recherche un médicament BDPM par nom ou CIP',
  description:
    "Recherche par CIP (7 ou 13 chiffres) ou par dénomination (ILIKE). Max 20 résultats. Sert à la saisie manuelle d'une boîte côté web.",
  tags: ['bdpm'],
  request: { query: BdpmSearchQuerySchema },
  responses: {
    200: {
      description: 'Résultats',
      content: { 'application/json': { schema: BdpmSearchResponseSchema } },
    },
    400: errorResponse('Paramètre `q` invalide'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/bdpm/resolve',
  summary: 'Résout un lot de CIP13 en médicaments (nom, forme, dosage…)',
  description:
    "Prend `cips` (CIP13 séparés par des virgules) et retourne les médicaments BDPM correspondants. Sert au front web à afficher les NOMS des médicaments sur une liste d'inventaire (le type Boite ne stocke que le cip13). Read-only, dédup + cap serveur. Un CIP inconnu est simplement absent du résultat.",
  tags: ['bdpm'],
  request: { query: BdpmResolveQuerySchema },
  responses: {
    200: {
      description: 'Médicaments résolus',
      content: { 'application/json': { schema: BdpmResolveResponseSchema } },
    },
    400: errorResponse('Paramètre `cips` invalide'),
  },
});
