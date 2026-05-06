// Moteur de synchronisation (#92 #94).
//
// Applique une opération issue du push mobile en respectant :
//  - **idempotence** : si `operation_id` a déjà été enregistré dans
//    `sync_operations_log`, on renvoie l'ack stocké sans rejouer.
//  - **AuthZ** : le user courant doit avoir un rôle suffisant sur
//    l'officine concernée (resolve via `partages`).
//  - **Last-write-wins** : si le serveur a une version plus récente
//    (`updated_at` > op.timestamp_local), l'op perd → ack `conflict`
//    avec snapshot serveur dans `server_version`.
//
// Scope POC : boîtes uniquement (cf. ADR pattern sync). Les autres
// entités sont à étendre dans des tickets dédiés.
import {
  boites,
  partages,
  syncOperationsLog,
  type Boite as BoiteRow,
  type Db,
} from '@piloo/db-schema';
import type { SyncAck, SyncOperation } from '@piloo/api-contract';
import { and, eq, isNull } from 'drizzle-orm';

import { serializeBoite } from '@/lib/boites/serialize';

type SyncStatus = 'applied' | 'conflict' | 'rejected';

interface ApplyContext {
  db: Db;
  userId: string;
  clientId: string;
}

export async function applyOperation(ctx: ApplyContext, op: SyncOperation): Promise<SyncAck> {
  // Idempotence
  const [existing] = await ctx.db
    .select()
    .from(syncOperationsLog)
    .where(eq(syncOperationsLog.operationId, op.id))
    .limit(1);
  if (existing) {
    return rebuildAck(
      existing.status,
      op.id,
      op.entity_id,
      existing.reason,
      existing.serverVersion,
    );
  }

  let ack: SyncAck;
  switch (op.type) {
    case 'create_boite':
      ack = await applyCreateBoite(ctx, op);
      break;
    case 'update_boite':
      ack = await applyUpdateBoite(ctx, op);
      break;
    case 'soft_delete_boite':
      ack = await applySoftDeleteBoite(ctx, op);
      break;
  }

  // Persister l'ack pour idempotence future.
  await ctx.db.insert(syncOperationsLog).values({
    operationId: op.id,
    clientId: ctx.clientId,
    userId: ctx.userId,
    type: op.type,
    entityType: op.entity_type,
    entityId: op.entity_id,
    payload: op.payload,
    timestampLocal: op.timestamp_local,
    status: ack.status,
    reason: ack.reason ?? null,
    serverVersion: ack.server_version ?? null,
  });

  return ack;
}

function rebuildAck(
  status: SyncStatus,
  operationId: string,
  entityId: string,
  reason: string | null,
  serverVersion: unknown,
): SyncAck {
  const ack: SyncAck = {
    operation_id: operationId,
    entity_id: entityId,
    status,
  };
  if (reason !== null) ack.reason = reason;
  if (serverVersion !== null && serverVersion !== undefined) {
    ack.server_version = serverVersion as SyncAck['server_version'];
  }
  return ack;
}

async function userHasWriteRoleOn(db: Db, userId: string, officineId: string): Promise<boolean> {
  const [row] = await db
    .select({ role: partages.role })
    .from(partages)
    .where(
      and(
        eq(partages.userId, userId),
        eq(partages.officineId, officineId),
        isNull(partages.deletedAt),
      ),
    )
    .limit(1);
  return row?.role === 'owner' || row?.role === 'editor';
}

async function applyCreateBoite(
  ctx: ApplyContext,
  op: Extract<SyncOperation, { type: 'create_boite' }>,
): Promise<SyncAck> {
  if (!(await userHasWriteRoleOn(ctx.db, ctx.userId, op.payload.officine_id))) {
    return rejected(op, 'forbidden');
  }

  // Idempotence applicative : si une boîte avec cet id existe déjà, on
  // considère l'op comme appliquée (évite les doublons sur retry).
  const [existing] = await ctx.db.select().from(boites).where(eq(boites.id, op.entity_id)).limit(1);
  if (existing) {
    return conflict(op, existing);
  }

  const [row] = await ctx.db
    .insert(boites)
    .values({
      id: op.entity_id,
      officineId: op.payload.officine_id,
      cip13: op.payload.cip13,
      lot: op.payload.lot ?? null,
      numeroSerie: op.payload.numero_serie ?? null,
      peremption: op.payload.peremption,
      unitesInitiales: op.payload.unites_initiales ?? null,
      unitesRestantes: op.payload.unites_restantes ?? null,
      notes: op.payload.notes ?? null,
      ajouteePar: ctx.userId,
    })
    .returning();
  if (!row) {
    return rejected(op, 'insert_failed');
  }
  return applied(op);
}

async function applyUpdateBoite(
  ctx: ApplyContext,
  op: Extract<SyncOperation, { type: 'update_boite' }>,
): Promise<SyncAck> {
  const [boite] = await ctx.db
    .select()
    .from(boites)
    .where(and(eq(boites.id, op.entity_id), isNull(boites.deletedAt)))
    .limit(1);
  if (!boite) {
    return rejected(op, 'not_found');
  }
  if (!(await userHasWriteRoleOn(ctx.db, ctx.userId, boite.officineId))) {
    return rejected(op, 'forbidden');
  }
  // LWW : si le serveur a une version plus récente que la modification
  // que le client a tenté de faire, l'op perd.
  if (boite.updatedAt.getTime() > op.timestamp_local) {
    return conflict(op, boite);
  }

  const [row] = await ctx.db
    .update(boites)
    .set({
      ...(op.payload.statut !== undefined && { statut: op.payload.statut }),
      ...(op.payload.unites_restantes !== undefined && {
        unitesRestantes: op.payload.unites_restantes,
      }),
      ...(op.payload.notes !== undefined && { notes: op.payload.notes }),
      updatedAt: new Date(),
    })
    .where(and(eq(boites.id, op.entity_id), isNull(boites.deletedAt)))
    .returning();
  return row ? applied(op) : rejected(op, 'update_failed');
}

async function applySoftDeleteBoite(
  ctx: ApplyContext,
  op: Extract<SyncOperation, { type: 'soft_delete_boite' }>,
): Promise<SyncAck> {
  const [boite] = await ctx.db.select().from(boites).where(eq(boites.id, op.entity_id)).limit(1);
  if (!boite) {
    return rejected(op, 'not_found');
  }
  if (boite.deletedAt) {
    // Déjà supprimée — idempotent
    return applied(op);
  }
  if (!(await userHasWriteRoleOn(ctx.db, ctx.userId, boite.officineId))) {
    return rejected(op, 'forbidden');
  }
  if (boite.updatedAt.getTime() > op.timestamp_local) {
    return conflict(op, boite);
  }

  await ctx.db
    .update(boites)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(eq(boites.id, op.entity_id));
  return applied(op);
}

function applied(op: SyncOperation): SyncAck {
  return {
    operation_id: op.id,
    entity_id: op.entity_id,
    status: 'applied',
  };
}

function rejected(op: SyncOperation, reason: string): SyncAck {
  return {
    operation_id: op.id,
    entity_id: op.entity_id,
    status: 'rejected',
    reason,
  };
}

function conflict(op: SyncOperation, server: BoiteRow): SyncAck {
  return {
    operation_id: op.id,
    entity_id: op.entity_id,
    status: 'conflict',
    server_version: serializeBoite(server),
  };
}
