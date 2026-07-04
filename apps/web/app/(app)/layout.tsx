// Layout app-shell pour les pages authentifiées (#73, gating #169).
// Sidebar à gauche + main content. Le `(app)` est un route group Next.js
// — n'apparaît pas dans l'URL, sert juste à scoper le layout.
//
// Gate auth : on `requireUser()` au layout — si pas de session, redirect
// vers /sign-in. Toutes les pages sous `(app)/` héritent de cette
// protection sans avoir à dupliquer la check.
import type { ReactNode } from 'react';

import { MobileTabBar, MobileTopBar } from '@/components/app/mobile-nav';
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
      <div className="flex min-h-screen bg-piloo-background">
        <Sidebar userName={session.user.name} userEmail={session.user.email} />
        <div className="flex min-w-0 flex-1 flex-col">
          <MobileTopBar />
          <main className="flex-1">
            {/* `.wrap` du redesign : colonne centrée, respirante, avec du
                padding bas pour ne pas passer sous la tab bar mobile. */}
            <div className="mx-auto max-w-[1080px] px-[18px] pb-28 pt-6 md:px-10 md:pb-[90px] md:pt-[34px]">
              {children}
            </div>
          </main>
          <MobileTabBar />
        </div>
      </div>
    </ActiveOfficineProvider>
  );
}
