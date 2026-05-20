// Helpers d'auth pour les API Routes (#43, parent #3 API foundation).
//
// Pattern : chaque guard renvoie soit le contexte requis (session, partage…)
// soit une `Response` HTTP prête à être retournée. L'API route choisit :
//
//   const auth = await requireAuth(request);
//   if (auth instanceof Response) return auth;
//   const partage = await requireRole(auth.user.id, officineId, ['owner', 'editor']);
//   if (partage instanceof Response) return partage;
//   // ... logique métier avec auth.user et partage.role
//
// On évite de jeter pour rester compatible avec le typage des handlers
// Next.js (qui retournent des Response). Les codes d'erreur suivent
// docs/api-contract.md §"Format des erreurs".
import { partages, type Partage } from '@piloo/db-schema';
import { and, eq, inArray, isNull } from 'drizzle-orm';

import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';

import { getAuth, type AuthInstance } from './server.ts';

export type Role = 'owner' | 'editor' | 'viewer';

interface AuthSession {
  user: { id: string; email: string };
  session: { id: string; expiresAt: Date };
}

interface RequireAuthOptions {
  // Injection d'instance pour les tests (testcontainers + createAuth).
  auth?: AuthInstance;
}

export async function requireAuth(
  request: Request,
  options: RequireAuthOptions = {},
): Promise<AuthSession | Response> {
  const auth = options.auth ?? getAuth();
  const session = await auth.api.getSession({ headers: request.headers });
  if (!session) {
    return apiErrorResponse('unauthorized', 'Authentication required.');
  }
  return {
    user: { id: session.user.id, email: session.user.email },
    session: { id: session.session.id, expiresAt: session.session.expiresAt },
  };
}

/// Guard admin : vérifie auth + email dans la whitelist ADMIN_EMAILS
/// (env var, comma-separated). Renvoie une Response 403 si l'user n'a
/// pas accès. À utiliser pour les routes /api/v1/admin/*.
///
/// Pas de système de rôles DB pour l'instant — on garde l'admin
/// minimal pour valider les résumés IA (#166). Si ça grossit on
/// passera sur une table `admin_users`.
export async function requireAdmin(
  request: Request,
  options: RequireAuthOptions = {},
): Promise<AuthSession | Response> {
  const session = await requireAuth(request, options);
  if (session instanceof Response) return session;
  const allowed = (process.env['ADMIN_EMAILS'] ?? '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter((e) => e.length > 0);
  if (!allowed.includes(session.user.email.toLowerCase())) {
    return apiErrorResponse('forbidden', 'Accès admin requis.');
  }
  return session;
}

interface RequireRoleOptions {
  // Injection pour les tests : DB Drizzle dédiée au testcontainer.
  db?: ReturnType<typeof getDb>;
}

export async function requireRole(
  userId: string,
  officineId: string,
  allowedRoles: readonly Role[],
  options: RequireRoleOptions = {},
): Promise<Partage | Response> {
  const db = options.db ?? getDb();
  const [partage] = await db
    .select()
    .from(partages)
    .where(
      and(
        eq(partages.userId, userId),
        eq(partages.officineId, officineId),
        isNull(partages.deletedAt),
        inArray(partages.role, allowedRoles as Role[]),
      ),
    )
    .limit(1);

  if (!partage) {
    // 404 plutôt que 403 quand le user n'a aucun partage : on ne révèle pas
    // l'existence d'une officine à laquelle il n'a pas accès. 403 si partage
    // présent mais rôle insuffisant, 404 sinon.
    const [anyPartage] = await db
      .select()
      .from(partages)
      .where(
        and(
          eq(partages.userId, userId),
          eq(partages.officineId, officineId),
          isNull(partages.deletedAt),
        ),
      )
      .limit(1);

    if (!anyPartage) {
      return apiErrorResponse('not_found', 'Officine introuvable.');
    }
    return apiErrorResponse(
      'forbidden',
      `Rôle insuffisant pour cette officine (requis: ${allowedRoles.join(' ou ')}).`,
      { current_role: anyPartage.role },
    );
  }
  return partage;
}
