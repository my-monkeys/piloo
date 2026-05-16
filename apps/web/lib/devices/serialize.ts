// Serializer DB → wire format pour /v1/devices (#124).
// Le `token` n'est PAS renvoyé au client — il identifie le device côté
// FCM, le client n'a pas besoin de le relire (il l'a déjà localement).
import type { Device as DeviceWire } from '@piloo/api-contract';
import type { Device } from '@piloo/db-schema';

export function serializeDevice(d: Device): DeviceWire {
  return {
    id: d.id,
    user_id: d.userId,
    platform: d.platform,
    app_version: d.appVersion,
    created_at: d.createdAt.toISOString(),
    last_seen_at: d.lastSeenAt.toISOString(),
  };
}
