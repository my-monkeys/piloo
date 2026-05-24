// Repository membres d'une officine (#339).
//
// Distinct de invitations/repo : ici on gère les partages déjà
// acceptés (acceptedAt != null, deletedAt == null). La création
// d'un membership passe TOUJOURS par invitations.acceptInvitation,
// jamais directement (sauf à la création de l'officine où l'owner
// est seedé inline).
import {
  invitations,
  partages,
  users,
  type Invitation,
  type Db,
  type Partage,
} from '@piloo/db-schema';
import { and, eq, gt, isNull } from 'drizzle-orm';

export interface MemberRow {
  partage: Partage;
  email: string;
  displayName: string;
}

/// Liste les membres ACTIFS (acceptedAt != null && deletedAt == null)
/// de l'officine, avec leur user pour l'affichage. L'ordre suit
/// invitedAt asc (owner historique en premier, derniers arrivés en
/// dernier).
export async function listMembers(db: Db, officineId: string): Promise<MemberRow[]> {
  const rows = await db
    .select({
      partage: partages,
      email: users.email,
      displayName: users.name,
    })
    .from(partages)
    .innerJoin(users, eq(partages.userId, users.id))
    .where(and(eq(partages.officineId, officineId), isNull(partages.deletedAt)))
    .orderBy(partages.invitedAt);
  return rows.filter((r) => r.partage.acceptedAt !== null);
}

/// Liste les invitations en attente (acceptedAt null, deletedAt null,
/// expiresAt > now) pour cette officine — différent de listMembers
/// car ce ne sont pas (encore) des membres.
export async function listPendingInvitations(
  db: Db,
  officineId: string,
  now: Date = new Date(),
): Promise<Invitation[]> {
  return db
    .select()
    .from(invitations)
    .where(
      and(
        eq(invitations.officineId, officineId),
        isNull(invitations.acceptedAt),
        isNull(invitations.deletedAt),
        gt(invitations.expiresAt, now),
      ),
    )
    .orderBy(invitations.createdAt);
}

/// Compte les owners actifs (acceptedAt set, deletedAt null).
/// Utilisé pour le garde-fou "dernier owner" avant un PATCH (rétrograde)
/// ou un DELETE.
export async function countActiveOwners(db: Db, officineId: string): Promise<number> {
  const rows = await db
    .select({ id: partages.id })
    .from(partages)
    .where(
      and(
        eq(partages.officineId, officineId),
        eq(partages.role, 'owner'),
        isNull(partages.deletedAt),
      ),
    );
  return rows.length;
}

export async function findMember(
  db: Db,
  officineId: string,
  userId: string,
): Promise<MemberRow | null> {
  const [row] = await db
    .select({
      partage: partages,
      email: users.email,
      displayName: users.name,
    })
    .from(partages)
    .innerJoin(users, eq(partages.userId, users.id))
    .where(
      and(
        eq(partages.officineId, officineId),
        eq(partages.userId, userId),
        isNull(partages.deletedAt),
      ),
    )
    .limit(1);
  return row ?? null;
}

/// Met à jour le rôle d'un membre. Retourne le membre mis à jour ou
/// null si introuvable. Le caller doit avoir vérifié le garde-fou
/// "dernier owner" en amont.
export async function updateMemberRole(
  db: Db,
  officineId: string,
  userId: string,
  role: 'owner' | 'editor' | 'viewer',
): Promise<MemberRow | null> {
  const now = new Date();
  await db
    .update(partages)
    .set({ role, updatedAt: now })
    .where(
      and(
        eq(partages.officineId, officineId),
        eq(partages.userId, userId),
        isNull(partages.deletedAt),
      ),
    );
  return findMember(db, officineId, userId);
}

/// Soft-delete d'un membre. Retourne true si effectif. Le caller doit
/// avoir vérifié le garde-fou "dernier owner".
export async function softDeleteMember(
  db: Db,
  officineId: string,
  userId: string,
): Promise<boolean> {
  const now = new Date();
  const rows = await db
    .update(partages)
    .set({ deletedAt: now, updatedAt: now })
    .where(
      and(
        eq(partages.officineId, officineId),
        eq(partages.userId, userId),
        isNull(partages.deletedAt),
      ),
    )
    .returning({ id: partages.id });
  return rows.length > 0;
}
