// Export RGPD des données personnelles d'un utilisateur (#158).
//
// Article 20 du RGPD : "droit à la portabilité" — l'utilisateur peut
// récupérer dans un format structuré, couramment utilisé et lisible
// par machine toutes les données personnelles le concernant.
//
// Périmètre : on exporte UNIQUEMENT les données dont l'utilisateur est
// concerné directement.
//   - son compte (profil, préférences, devices)
//   - les officines dont il est propriétaire (avec contenu : boîtes,
//     ordonnances, prescriptions, prises planifiées)
//   - les officines partagées avec lui : on n'exporte QUE la relation
//     de partage (rôle, dates), pas le contenu — ces données appartiennent
//     au propriétaire de l'officine au sens RGPD.
//   - les alertes qui lui sont adressées
//
// Format : JSON UTF-8, snake_case, version d'API explicite pour faciliter
// les évolutions sans casser un dump existant.
import {
  alertes,
  boites,
  devices,
  officines,
  ordonnances,
  partages,
  prescriptions,
  prisesPlanifiees,
  users,
  type Db,
} from '@piloo/db-schema';
import { and, eq, inArray, isNull } from 'drizzle-orm';

export const EXPORT_FORMAT_VERSION = '1.0';

export interface UserDataExport {
  format_version: typeof EXPORT_FORMAT_VERSION;
  generated_at: string;
  user_id: string;
  account: Record<string, unknown>;
  preferences: unknown;
  devices: Record<string, unknown>[];
  /** Officines dont l'user est propriétaire — contenu intégral. */
  owned_officines: OwnedOfficineExport[];
  /** Partages dont l'user est destinataire — métadonnées seulement. */
  shared_officines: SharedOfficineExport[];
  alertes: Record<string, unknown>[];
}

export interface OwnedOfficineExport {
  officine: Record<string, unknown>;
  partages: Record<string, unknown>[];
  boites: Record<string, unknown>[];
  ordonnances: OrdonnanceExport[];
}

export interface OrdonnanceExport {
  ordonnance: Record<string, unknown>;
  prescriptions: Record<string, unknown>[];
  prises_planifiees: Record<string, unknown>[];
}

export interface SharedOfficineExport {
  officine_id: string;
  officine_nom: string;
  role: string;
  invited_at: string;
  accepted_at: string | null;
}

function serializeRow(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row)) {
    out[key] = value instanceof Date ? value.toISOString() : value;
  }
  return out;
}

export async function exportUserData(db: Db, userId: string): Promise<UserDataExport> {
  const [userRow] = await db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!userRow) throw new Error('user not found');

  // ----- compte + préférences -----
  const { preferences, ...accountFields } = userRow;
  const account = serializeRow(accountFields);

  // ----- devices -----
  const deviceRows = await db.select().from(devices).where(eq(devices.userId, userId));

  // ----- alertes -----
  const alerteRows = await db.select().from(alertes).where(eq(alertes.userId, userId));

  // ----- officines en propre -----
  const ownedOfficines = await db
    .select()
    .from(officines)
    .where(and(eq(officines.proprietaireUserId, userId), isNull(officines.deletedAt)));

  const owned: OwnedOfficineExport[] = [];
  for (const off of ownedOfficines) {
    owned.push(await exportOwnedOfficine(db, off));
  }

  // ----- partages reçus (officines accessibles non-propriétaire) -----
  const partageRows = await db
    .select()
    .from(partages)
    .where(and(eq(partages.userId, userId), isNull(partages.deletedAt)));
  const ownedIds = new Set(ownedOfficines.map((o) => o.id));
  const sharedPartages = partageRows.filter((p) => !ownedIds.has(p.officineId));
  const sharedOfficineIds = sharedPartages.map((p) => p.officineId);
  const sharedOfficineRows =
    sharedOfficineIds.length === 0
      ? []
      : await db
          .select({ id: officines.id, nom: officines.nom })
          .from(officines)
          .where(inArray(officines.id, sharedOfficineIds));
  const nomById = new Map(sharedOfficineRows.map((o) => [o.id, o.nom]));
  const shared: SharedOfficineExport[] = sharedPartages.map((p) => ({
    officine_id: p.officineId,
    officine_nom: nomById.get(p.officineId) ?? '',
    role: p.role,
    invited_at: p.invitedAt.toISOString(),
    accepted_at: p.acceptedAt?.toISOString() ?? null,
  }));

  return {
    format_version: EXPORT_FORMAT_VERSION,
    generated_at: new Date().toISOString(),
    user_id: userId,
    account,
    preferences,
    devices: deviceRows.map(serializeRow),
    owned_officines: owned,
    shared_officines: shared,
    alertes: alerteRows.map(serializeRow),
  };
}

async function exportOwnedOfficine(
  db: Db,
  off: typeof officines.$inferSelect,
): Promise<OwnedOfficineExport> {
  const officineSerial = serializeRow(off);

  const partageRows = await db.select().from(partages).where(eq(partages.officineId, off.id));

  const boiteRows = await db.select().from(boites).where(eq(boites.officineId, off.id));

  const ordonnanceRows = await db
    .select()
    .from(ordonnances)
    .where(eq(ordonnances.officineId, off.id));

  const ords: OrdonnanceExport[] = [];
  for (const o of ordonnanceRows) {
    const prescRows = await db
      .select()
      .from(prescriptions)
      .where(eq(prescriptions.ordonnanceId, o.id));
    const priseRows =
      prescRows.length === 0
        ? []
        : await db
            .select()
            .from(prisesPlanifiees)
            .where(
              inArray(
                prisesPlanifiees.prescriptionId,
                prescRows.map((p) => p.id),
              ),
            );
    ords.push({
      ordonnance: serializeRow(o),
      prescriptions: prescRows.map(serializeRow),
      prises_planifiees: priseRows.map(serializeRow),
    });
  }

  return {
    officine: officineSerial,
    partages: partageRows.map(serializeRow),
    boites: boiteRows.map(serializeRow),
    ordonnances: ords,
  };
}
