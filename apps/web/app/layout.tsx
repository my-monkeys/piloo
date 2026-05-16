import type { ReactNode } from 'react';

import { PilooQueryProvider } from '@/lib/api/query-client-provider';

export const metadata = {
  title: 'Piloo',
  description: 'Carnet numérique de médicaments — aide-mémoire personnel.',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr">
      <body>
        <PilooQueryProvider>{children}</PilooQueryProvider>
      </body>
    </html>
  );
}
