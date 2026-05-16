// Schémas Zod du contrat /api/v1/devices (#124).
//
// Endpoints pour l'enregistrement des devices push (FCM iOS/Android +
// future web push). Un user a N devices ; le couple (user, token) est
// unique côté DB → POST idempotent (réenregistrer le même token →
// rafraîchit `last_seen_at` au lieu de doublonner).
//
// Convention : la suppression d'un device se fait par son id (renvoyé
// au POST), pas par le token (qui peut changer côté FCM).
import { z } from 'zod';

import { registry } from '../openapi.ts';

const DevicePlatformEnum = z.enum(['ios', 'android', 'web']);

export const DeviceSchema = z
  .object({
    id: z.uuid(),
    user_id: z.uuid(),
    platform: DevicePlatformEnum,
    app_version: z.string().nullable(),
    created_at: z.iso.datetime(),
    last_seen_at: z.iso.datetime(),
  })
  .openapi('Device');

export const RegisterDeviceInputSchema = z
  .object({
    // FCM token ou équivalent web push. Format libre — c'est le
    // provider qui l'émet. Min 16 (les tokens FCM font 100+ chars,
    // 16 est un garde-fou anti-payload vide).
    token: z.string().min(16).max(4096),
    platform: DevicePlatformEnum,
    app_version: z.string().max(64).optional(),
  })
  .openapi('RegisterDeviceInput');

export const ListDevicesResponseSchema = z
  .object({ items: z.array(DeviceSchema) })
  .openapi('ListDevicesResponse');

export type Device = z.infer<typeof DeviceSchema>;
export type RegisterDeviceInput = z.infer<typeof RegisterDeviceInputSchema>;
export type ListDevicesResponse = z.infer<typeof ListDevicesResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('DevicesApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/devices',
  summary: "Liste les devices enregistrés de l'utilisateur courant",
  tags: ['devices'],
  responses: {
    200: {
      description: 'Liste',
      content: { 'application/json': { schema: ListDevicesResponseSchema } },
    },
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'post',
  path: '/v1/devices',
  summary: 'Enregistre ou rafraîchit un device pour les push notifications',
  description:
    'Idempotent sur le couple (user, token) : si le token existe déjà ' +
    "pour l'utilisateur, `last_seen_at` est mis à jour ; la même row est " +
    'renvoyée. Sinon, une nouvelle row est créée.',
  tags: ['devices'],
  request: {
    body: { content: { 'application/json': { schema: RegisterDeviceInputSchema } } },
  },
  responses: {
    200: {
      description: 'Device mis à jour (existait déjà)',
      content: { 'application/json': { schema: DeviceSchema } },
    },
    201: {
      description: 'Device créé',
      content: { 'application/json': { schema: DeviceSchema } },
    },
    400: errorResponse('Body invalide'),
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'delete',
  path: '/v1/devices/{id}',
  summary: 'Supprime (soft-delete) un device — typiquement à la déconnexion',
  description:
    "Réservé au user propriétaire du device. Le device n'est pas " +
    'supprimé physiquement (soft-delete) pour pouvoir tracer les ' +
    'invalidations futures côté FCM.',
  tags: ['devices'],
  request: { params: z.object({ id: z.uuid() }) },
  responses: {
    204: { description: 'Supprimé' },
    401: errorResponse('Non authentifié'),
    404: errorResponse('Device inconnu ou pas au user courant'),
  },
});
