// Conversion DB → contrat API pour ordonnances + prescriptions (#106).
import type {
  Ordonnance as OrdonnanceRow,
  Prescription as PrescriptionRow,
} from '@piloo/db-schema';
import type {
  Ordonnance as OrdonnanceDto,
  OrdonnanceWithPrescriptions as OrdonnanceWithPrescriptionsDto,
  Prescription as PrescriptionDto,
} from '@piloo/api-contract';

export function serializeOrdonnance(row: OrdonnanceRow): OrdonnanceDto {
  return {
    id: row.id,
    officine_id: row.officineId,
    prescripteur: row.prescripteur,
    date_prescription: row.datePrescription,
    source: row.source,
    photo_url: row.photoUrl,
    notes: row.notes,
    saisie_par: row.saisiePar,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
    deleted_at: row.deletedAt?.toISOString() ?? null,
  };
}

export function serializePrescription(row: PrescriptionRow): PrescriptionDto {
  return {
    id: row.id,
    ordonnance_id: row.ordonnanceId,
    cip13: row.cip13,
    cis: row.cis,
    nom_texte: row.nomTexte,
    // La posologie DB et la posologie DTO partagent la forme, mais la DB
    // typée en `readonly` ne se cast pas automatiquement en mutable côté DTO.
    posologie: {
      ...row.posologie,
      moments: row.posologie.moments ? [...row.posologie.moments] : undefined,
      horaires: row.posologie.horaires ? [...row.posologie.horaires] : undefined,
    },
    duree_jours: row.dureeJours,
    indication: row.indication,
    notes: row.notes,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
    deleted_at: row.deletedAt?.toISOString() ?? null,
  };
}

export function serializeOrdonnanceWithPrescriptions(
  ord: OrdonnanceRow,
  prescs: readonly PrescriptionRow[],
): OrdonnanceWithPrescriptionsDto {
  return {
    ...serializeOrdonnance(ord),
    prescriptions: prescs.map(serializePrescription),
  };
}
