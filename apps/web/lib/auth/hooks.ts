// Hooks de cycle de vie utilisateur (#69). Branchés sur Better Auth via
// `databaseHooks.user.create.after` (cf. lib/auth/server.ts).
//
// Pourquoi ici plutôt qu'inline dans server.ts : le hook a une vraie
// logique métier (création d'officine perso + partage owner) avec ses
// propres tests d'intégration. L'isoler permet aussi de l'invoquer
// directement dans les tests sans passer par le handler Better Auth.
import { officines, partages, type Db } from '@piloo/db-schema';

interface NewUser {
  id: string;
  name: string;
  typeCompte?: string;
}

export interface CreatedOfficineRefs {
  officineId: string;
  partageId: string;
}

/**
 * Crée l'officine perso + le partage owner pour un user `particulier`.
 * No-op pour les comptes `pro` — ils créent leurs officines patient à
 * la demande.
 *
 * Idempotent par construction : appelé une seule fois par
 * databaseHooks.user.create.after. Si on a besoin d'une garantie
 * d'unicité côté DB un jour, ajouter un index unique partiel
 * (proprietaire_user_id, type='perso') WHERE deleted_at IS NULL.
 */
export async function createPersonalOfficineFor(
  db: Db,
  user: NewUser,
): Promise<CreatedOfficineRefs | null> {
  if (user.typeCompte !== 'particulier') {
    return null;
  }

  const [officine] = await db
    .insert(officines)
    .values({
      nom: 'Mon officine',
      type: 'perso',
      proprietaireUserId: user.id,
    })
    .returning({ id: officines.id });
  if (!officine) {
    throw new Error('createPersonalOfficineFor: officines insert returned no row');
  }

  const [partage] = await db
    .insert(partages)
    .values({
      officineId: officine.id,
      userId: user.id,
      role: 'owner',
      invitedAt: new Date(),
      acceptedAt: new Date(),
    })
    .returning({ id: partages.id });
  if (!partage) {
    throw new Error('createPersonalOfficineFor: partages insert returned no row');
  }

  return { officineId: officine.id, partageId: partage.id };
}
