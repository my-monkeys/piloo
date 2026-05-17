// Schéma OpenAPI export RGPD (#158). On documente uniquement l'endpoint
// — le payload retourné est une archive JSON volumineuse à structure
// récursive (devices, officines, ordonnances → prescriptions → prises),
// non utile à typer côté contrat client (le destinataire est l'humain).
import { z } from 'zod';

import { registry } from '../openapi.ts';

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('ExportDataApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'post',
  path: '/v1/me/export',
  summary: "Export RGPD article 20 — toutes les données personnelles de l'utilisateur",
  description:
    'Retourne un JSON téléchargeable (Content-Disposition: attachment) contenant : compte, préférences, devices, officines en propre (avec boîtes/ordonnances/prescriptions/prises), partages reçus (métadonnées seulement), alertes.',
  tags: ['rgpd'],
  responses: {
    200: {
      description: 'Archive JSON des données personnelles',
      content: { 'application/json': { schema: z.record(z.string(), z.unknown()) } },
    },
    401: errorResponse('Non authentifié'),
  },
});
