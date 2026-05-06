// Schémas Zod du contrat /api/v1/sync (#92 #93 #94).
// Cf. docs/api-contract.md §"Synchronisation" et docs/architecture.md
// §"Synchronisation" (pattern operations log + last-write-wins).
//
// Scope POC : opérations sur les boîtes uniquement (`create_boite`,
// `update_boite`, `soft_delete_boite`). Les autres entités (officines,
// partages, ordonnances, prescriptions, prises_planifiees, alertes)
// suivront dans des tickets dédiés.
import { z } from 'zod';

import { registry } from '../openapi.ts';
import { BoiteSchema, CreateBoiteInputSchema, UpdateBoiteInputSchema } from './boites.ts';

// Ack par opération
export const SyncAckStatusEnum = z.enum(['applied', 'conflict', 'rejected']);

const SoftDeletePayloadSchema = z.object({}).strict();

const OperationCreateBoiteSchema = z.object({
  id: z.uuid(),
  type: z.literal('create_boite'),
  entity_type: z.literal('boite'),
  entity_id: z.uuid(),
  payload: CreateBoiteInputSchema.extend({
    officine_id: z.uuid(),
  }),
  timestamp_local: z.number().int().nonnegative(),
});

const OperationUpdateBoiteSchema = z.object({
  id: z.uuid(),
  type: z.literal('update_boite'),
  entity_type: z.literal('boite'),
  entity_id: z.uuid(),
  payload: UpdateBoiteInputSchema,
  timestamp_local: z.number().int().nonnegative(),
});

const OperationSoftDeleteBoiteSchema = z.object({
  id: z.uuid(),
  type: z.literal('soft_delete_boite'),
  entity_type: z.literal('boite'),
  entity_id: z.uuid(),
  payload: SoftDeletePayloadSchema,
  timestamp_local: z.number().int().nonnegative(),
});

export const SyncOperationSchema = z.discriminatedUnion('type', [
  OperationCreateBoiteSchema,
  OperationUpdateBoiteSchema,
  OperationSoftDeleteBoiteSchema,
]);

const MAX_BATCH = 100;

export const SyncPushRequestSchema = z
  .object({
    client_id: z.string().min(1).max(120),
    operations: z.array(SyncOperationSchema).min(1).max(MAX_BATCH),
  })
  .openapi('SyncPushRequest');

export const SyncAckSchema = z
  .object({
    operation_id: z.uuid(),
    entity_id: z.uuid(),
    status: SyncAckStatusEnum,
    reason: z.string().optional(),
    server_version: BoiteSchema.optional(),
  })
  .openapi('SyncAck');

export const SyncPushResponseSchema = z
  .object({
    acks: z.array(SyncAckSchema),
    server_time: z.iso.datetime(),
  })
  .openapi('SyncPushResponse');

export const SyncPullResponseSchema = z
  .object({
    entities: z.object({
      boites: z.array(BoiteSchema),
    }),
    deleted: z.object({
      boites: z.array(z.uuid()),
    }),
    server_time: z.iso.datetime(),
  })
  .openapi('SyncPullResponse');

export type SyncOperation = z.infer<typeof SyncOperationSchema>;
export type SyncPushRequest = z.infer<typeof SyncPushRequestSchema>;
export type SyncAck = z.infer<typeof SyncAckSchema>;
export type SyncPushResponse = z.infer<typeof SyncPushResponseSchema>;
export type SyncPullResponse = z.infer<typeof SyncPullResponseSchema>;

const ApiErrorSchema = z
  .object({
    error: z.object({
      code: z.string(),
      message: z.string(),
      details: z.record(z.string(), z.unknown()).optional(),
    }),
  })
  .openapi('SyncApiError');

const errorResponse = (description: string) => ({
  description,
  content: { 'application/json': { schema: ApiErrorSchema } },
});

registry.registerPath({
  method: 'post',
  path: '/v1/sync/push',
  summary: "Pousse un batch d'opérations locales vers le serveur",
  description:
    'Idempotent par operation_id. Maximum 100 opérations par requête. Renvoie un ack par opération (applied | conflict | rejected).',
  tags: ['sync'],
  request: {
    body: { content: { 'application/json': { schema: SyncPushRequestSchema } } },
  },
  responses: {
    200: {
      description: 'Acks',
      content: { 'application/json': { schema: SyncPushResponseSchema } },
    },
    400: errorResponse('Body invalide ou batch > 100'),
    401: errorResponse('Non authentifié'),
  },
});

registry.registerPath({
  method: 'get',
  path: '/v1/sync/pull',
  summary: 'Récupère les entités modifiées depuis un timestamp',
  description:
    "Renvoie toutes les entités accessibles à l'utilisateur dont updated_at > since. Les soft-deletes apparaissent dans `deleted[]` plutôt que dans `entities[]`.",
  tags: ['sync'],
  request: {
    query: z.object({
      since: z.iso.datetime().optional(),
      limit: z.coerce.number().int().min(1).max(500).optional(),
    }),
  },
  responses: {
    200: {
      description: 'Snapshot incremental',
      content: { 'application/json': { schema: SyncPullResponseSchema } },
    },
    400: errorResponse('Paramètres invalides'),
    401: errorResponse('Non authentifié'),
  },
});
