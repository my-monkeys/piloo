// Layout app-shell pour les pages authentifiées (#73). Sidebar à gauche
// + main content. Le `(app)` est un route group Next.js — n'apparaît
// pas dans l'URL, sert juste à scoper le layout.
import type { ReactNode } from 'react';

import { Sidebar } from '@/components/app/sidebar';
import { ActiveOfficineProvider } from '@/lib/officines/active-officine';

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <ActiveOfficineProvider>
      <div className="flex min-h-screen">
        <Sidebar />
        <main className="flex-1 p-8 max-w-5xl">{children}</main>
      </div>
    </ActiveOfficineProvider>
  );
}
