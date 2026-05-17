// Helper de lecture de session côté Server Components / Server Actions
// (#169).
//
// Pattern : on lit le cookie depuis `next/headers`, on demande à Better
// Auth de résoudre la session. Retourne l'objet session minimal ou `null`.
//
// Pour les pages qui exigent un user connecté, utiliser `requireUser()`
// qui redirige vers /sign-in si la session est absente.
import 'server-only';

import { headers } from 'next/headers';
import { redirect } from 'next/navigation';

import { getAuth } from './server.ts';

export interface ServerSession {
  user: { id: string; email: string; name: string };
  expiresAt: Date;
}

export async function getServerSession(): Promise<ServerSession | null> {
  const hdrs = await headers();
  const session = await getAuth().api.getSession({ headers: hdrs });
  if (!session) return null;
  return {
    user: {
      id: session.user.id,
      email: session.user.email,
      name: session.user.name,
    },
    expiresAt: session.session.expiresAt,
  };
}

/**
 * À utiliser dans un Server Component ou une Server Action quand le
 * code en dessous suppose qu'on a un user. Si pas de session, redirige
 * vers `/sign-in?redirect=<current>` pour ramener l'utilisateur après
 * login.
 *
 * Le `currentPath` est lu depuis le header `x-pathname` posé par le
 * middleware (`apps/web/middleware.ts`) — Next.js n'expose pas le
 * pathname directement aux Server Components.
 */
export async function requireUser(fallbackPath = '/dashboard'): Promise<ServerSession> {
  const hdrs = await headers();
  const session = await getAuth().api.getSession({ headers: hdrs });
  if (!session) {
    const currentPath = hdrs.get('x-pathname') ?? fallbackPath;
    const target = `/sign-in?redirect=${encodeURIComponent(currentPath)}`;
    redirect(target);
  }
  return {
    user: {
      id: session.user.id,
      email: session.user.email,
      name: session.user.name,
    },
    expiresAt: session.session.expiresAt,
  };
}
