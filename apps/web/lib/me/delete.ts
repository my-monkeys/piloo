// Suppression de compte avec délai 7 jours (#159).
//
// Cycle :
//   1. L'utilisateur demande la suppression → on set `users.deleted_at`
//      à la date courante. Le compte reste fonctionnel (sign-in autorisé,
//      lecture autorisée) pour permettre une restauration en self-service.
//   2. Pendant 7 jours, l'utilisateur peut cliquer "annuler la suppression"
//      → on clear `deleted_at`.
//   3. Au-delà de 7 jours, le cron `anonymize-accounts` (#159) anonymise
//      le compte :
//      - email → `deleted-{uuid}@piloo.local` (rend la reconnexion impossible
//        sans casser les FKs sur sessions/accounts/alertes/etc.)
//      - identité (name, nom, prenom, telephone, image) → valeurs vides
//      - preferences → {}
//      - les officines en propre sont soft-deletées (cascade applicative)
//      - les sessions/accounts Better Auth sont supprimés (hard delete OK,
//        ce sont des données techniques, pas du contenu utilisateur).
//
// Email de confirmation : le branchement à Brevo (#132) sera fait dans
// un autre ticket — pour le moment on logge l'événement et on retourne OK.
import { accounts, officines, sessions, users, type Db } from '@piloo/db-schema';
import { and, eq, isNotNull, isNull, lt } from 'drizzle-orm';

import { log } from '@/lib/server/logger';

/** Délai en jours entre la demande de suppression et l'anonymisation. */
export const DELETION_GRACE_DAYS = 7;

const MS_PER_DAY = 24 * 60 * 60 * 1000;

export interface RequestDeletionResult {
  deletedAt: Date;
  /** Date à laquelle le compte deviendra non récupérable. */
  scheduledAnonymizationAt: Date;
}

export async function requestAccountDeletion(
  db: Db,
  userId: string,
  now: Date = new Date(),
): Promise<RequestDeletionResult> {
  const [row] = await db
    .update(users)
    .set({ deletedAt: now, updatedAt: now })
    .where(eq(users.id, userId))
    .returning({ id: users.id, deletedAt: users.deletedAt, email: users.email });
  if (!row?.deletedAt) {
    throw new Error('requestAccountDeletion: user not found or no deletedAt');
  }
  const scheduled = new Date(row.deletedAt.getTime() + DELETION_GRACE_DAYS * MS_PER_DAY);
  log.info('account.delete.requested', {
    user_id: userId,
    scheduled_anonymization_at: scheduled.toISOString(),
  });
  // TODO #134 : envoyer l'email de confirmation via Brevo.
  return { deletedAt: row.deletedAt, scheduledAnonymizationAt: scheduled };
}

export async function restoreAccount(db: Db, userId: string): Promise<boolean> {
  const [row] = await db
    .update(users)
    .set({ deletedAt: null, updatedAt: new Date() })
    .where(and(eq(users.id, userId), isNotNull(users.deletedAt)))
    .returning({ id: users.id });
  if (!row) return false;
  log.info('account.delete.restored', { user_id: userId });
  return true;
}

export interface AnonymizeResult {
  anonymized: number;
}

/**
 * Anonymise tous les comptes dont `deleted_at < now - 7 jours`. Idempotent :
 * un compte déjà anonymisé (email préfixé `deleted-`) ne sera pas re-touché.
 */
export async function anonymizeExpiredAccounts(
  db: Db,
  now: Date = new Date(),
): Promise<AnonymizeResult> {
  const cutoff = new Date(now.getTime() - DELETION_GRACE_DAYS * MS_PER_DAY);
  const expired = await db
    .select({ id: users.id, email: users.email })
    .from(users)
    .where(and(isNotNull(users.deletedAt), lt(users.deletedAt, cutoff)));

  let anonymized = 0;
  for (const u of expired) {
    if (u.email.startsWith('deleted-')) continue; // déjà anonymisé
    await anonymizeOne(db, u.id);
    anonymized += 1;
  }
  log.info('cron.anonymize_accounts.done', { anonymized, candidates: expired.length });
  return { anonymized };
}

async function anonymizeOne(db: Db, userId: string): Promise<void> {
  await db.transaction(async (tx) => {
    const placeholderEmail = `deleted-${userId}@piloo.local`;
    await tx
      .update(users)
      .set({
        email: placeholderEmail,
        name: 'Compte supprimé',
        nom: '',
        prenom: '',
        telephone: null,
        image: null,
        preferences: {},
        updatedAt: new Date(),
      })
      .where(eq(users.id, userId));

    // Soft-delete les officines en propre — la cascade applicative est
    // gérée par les services métier (boites, ordonnances, etc. restent en
    // place tant qu'on n'a pas un hard purge ; le filtre officines.deleted_at
    // empêche déjà toute lecture).
    await tx
      .update(officines)
      .set({ deletedAt: new Date(), updatedAt: new Date() })
      .where(and(eq(officines.proprietaireUserId, userId), isNull(officines.deletedAt)));

    // Better Auth : supprimer sessions + accounts (re-sign-in impossible).
    await tx.delete(sessions).where(eq(sessions.userId, userId));
    await tx.delete(accounts).where(eq(accounts.userId, userId));
  });
}
