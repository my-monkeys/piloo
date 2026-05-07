// Préférences notifications par canal × type (#138).
//
// Source produit : écran mobile #155 (apps/mobile/lib/features/settings/
// presentation/notifications_screen.dart). 5 types d'événements × 3
// canaux (push / email / sms). Format persisté dans `users.preferences`
// JSONB sous la clé `notifications`.
//
// Défauts produits :
//   - rappel_prise          : push ON, email/sms OFF
//   - peremption            : push ON, email ON, sms OFF
//   - stock_bas             : push ON, email/sms OFF
//   - partage               : push ON, email ON, sms OFF
//   - manque_signale        : push ON, email/sms OFF
//
// Le SMS est exposé dans le contrat mais l'envoi réel sera bridé tant
// que le téléphone n'est pas vérifié — c'est validé côté service
// d'envoi, pas dans ce schéma de préférences.
import { z } from 'zod';

import { registry } from '../openapi.ts';

const ChannelsSchema = z
  .object({
    push: z.boolean(),
    email: z.boolean(),
    sms: z.boolean(),
  })
  .openapi('NotifChannels');

export const NotifPreferencesSchema = z
  .object({
    rappel_prise: ChannelsSchema,
    peremption: ChannelsSchema,
    stock_bas: ChannelsSchema,
    partage: ChannelsSchema,
    manque_signale: ChannelsSchema,
  })
  .openapi('NotifPreferences');

export const NotifPreferencesResponseSchema = NotifPreferencesSchema.openapi(
  'NotifPreferencesResponse',
);

export const UpdateNotifPreferencesInputSchema = NotifPreferencesSchema.openapi(
  'UpdateNotifPreferencesInput',
);

export type NotifPreferences = z.infer<typeof NotifPreferencesSchema>;

export const DEFAULT_NOTIF_PREFERENCES: NotifPreferences = {
  rappel_prise: { push: true, email: false, sms: false },
  peremption: { push: true, email: true, sms: false },
  stock_bas: { push: true, email: false, sms: false },
  partage: { push: true, email: true, sms: false },
  manque_signale: { push: true, email: false, sms: false },
};

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('NotifPrefsApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/me/preferences/notifications',
  summary: "Préférences notifications de l'utilisateur courant",
  description:
    'Renvoie les préférences persistées, fusionnées avec les défauts produit pour les types absents.',
  tags: ['preferences'],
  responses: {
    200: {
      description: 'Préférences',
      content: { 'application/json': { schema: NotifPreferencesResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'put',
  path: '/v1/me/preferences/notifications',
  summary: 'Met à jour les préférences notifications',
  description: 'Remplacement complet (PUT). Le client envoie les 5 types × 3 canaux.',
  tags: ['preferences'],
  request: {
    body: { content: { 'application/json': { schema: UpdateNotifPreferencesInputSchema } } },
  },
  responses: {
    200: {
      description: 'Préférences mises à jour',
      content: { 'application/json': { schema: NotifPreferencesResponseSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
  },
});
