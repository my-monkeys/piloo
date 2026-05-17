// Layout app-shell pour les pages authentifiées (#73, gating #169).
// Sidebar à gauche + main content. Le `(app)` est un route group Next.js
// — n'apparaît pas dans l'URL, sert juste à scoper le layout.
//
// Gate auth : on `requireUser()` au layout — si pas de session, redirect
// vers /sign-in. Toutes les pages sous `(app)/` héritent de cette
// protection sans avoir à dupliquer la check.
import type { ReactNode } from 'react';

import { Sidebar } from '@/components/app/sidebar';
import { requireUser } from '@/lib/auth/session';
import { ActiveOfficineProvider } from '@/lib/officines/active-officine';

export default async function AppLayout({ children }: { children: ReactNode }) {
  // `requireUser()` lit le pathname courant depuis le header
  // `x-pathname` (posé par middleware.ts) pour construire un
  // `?redirect=<actuel>` qui ramènera l'utilisateur à sa page d'origine.
  const session = await requireUser();
  return (
    <ActiveOfficineProvider>
      <div className="flex min-h-screen">
        <Sidebar userName={session.user.name} userEmail={session.user.email} />
        <main className="flex-1 p-8 max-w-5xl">{children}</main>
      </div>
    </ActiveOfficineProvider>
  );
}
