// Repository des devices (#124). Centralise les queries pour les
// handlers POST / GET / DELETE.
//
// Le couple `(user_id, token)` est UNIQUE en DB → on s'appuie dessus
// pour faire un upsert idempotent côté `registerDevice`.
import { devices, type Db, type Device } from '@piloo/db-schema';
import { and, desc, eq, isNull } from 'drizzle-orm';

export interface RegisterDeviceParams {
  userId: string;
  token: string;
  platform: 'ios' | 'android' | 'web';
  appVersion?: string | undefined;
}

export interface RegisterDeviceResult {
  device: Device;
  /** `true` si une nouvelle ligne a été insérée, `false` si l'existante a été rafraîchie. */
  created: boolean;
}

/**
 * Upsert idempotent : si (user, token) existe déjà → refresh
 * `last_seen_at` + `updated_at` (et undelete si soft-deleted). Sinon
 * insert. Renvoie la row finale + un flag "created" pour que le handler
 * choisisse le bon code HTTP (201 vs 200).
 */
export async function registerDevice(
  db: Db,
  params: RegisterDeviceParams,
): Promise<RegisterDeviceResult> {
  const now = new Date();
  return db.transaction(async (tx) => {
    const [existing] = await tx
      .select()
      .from(devices)
      .where(and(eq(devices.userId, params.userId), eq(devices.token, params.token)))
      .limit(1);

    if (existing) {
      const [updated] = await tx
        .update(devices)
        .set({
          platform: params.platform,
          appVersion: params.appVersion ?? existing.appVersion,
          lastSeenAt: now,
          updatedAt: now,
          // Undelete si l'utilisateur réenregistre un token qu'on avait
          // marqué invalide — c'est un re-login depuis le même device.
          deletedAt: null,
        })
        .where(eq(devices.id, existing.id))
        .returning();
      if (!updated) throw new Error('registerDevice: update returned no row');
      return { device: updated, created: false };
    }

    const [inserted] = await tx
      .insert(devices)
      .values({
        userId: params.userId,
        token: params.token,
        platform: params.platform,
        appVersion: params.appVersion ?? null,
      })
      .returning();
    if (!inserted) throw new Error('registerDevice: insert returned no row');
    return { device: inserted, created: true };
  });
}

export async function listDevicesForUser(db: Db, userId: string): Promise<Device[]> {
  return db
    .select()
    .from(devices)
    .where(and(eq(devices.userId, userId), isNull(devices.deletedAt)))
    .orderBy(desc(devices.lastSeenAt));
}

/**
 * Soft-delete d'un device, scopé au user — on ne supprime jamais un
 * device qui appartient à un autre user. Renvoie `true` si un row a été
 * affecté (soft-deleted), `false` si introuvable / déjà supprimé.
 */
export async function softDeleteDevice(
  db: Db,
  params: { userId: string; deviceId: string },
): Promise<boolean> {
  const now = new Date();
  const [row] = await db
    .update(devices)
    .set({ deletedAt: now, updatedAt: now })
    .where(
      and(
        eq(devices.id, params.deviceId),
        eq(devices.userId, params.userId),
        isNull(devices.deletedAt),
      ),
    )
    .returning({ id: devices.id });
  return Boolean(row);
}

/**
 * Marque un token comme invalide — typiquement appelé par le worker
 * de notification quand FCM répond `UNREGISTERED` ou `INVALID_ARGUMENT`.
 * Soft-delete par `token`, scopé global (pas par user) — c'est une
 * action machine, pas user-driven.
 */
export async function markTokenInvalid(db: Db, token: string): Promise<number> {
  const now = new Date();
  const rows = await db
    .update(devices)
    .set({ deletedAt: now, updatedAt: now })
    .where(and(eq(devices.token, token), isNull(devices.deletedAt)))
    .returning({ id: devices.id });
  return rows.length;
}
