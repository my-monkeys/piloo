// Carte de contenu du redesign (#370) — coins arrondis, bordure douce, ombre
// discrète. Réutilisée sur le tableau de bord, la timeline, les rappels.
import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

export function Panel({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <section
      className={cn(
        'rounded-2xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-surface p-5 shadow-[0_1px_2px_rgba(37,42,48,.03),0_10px_26px_-18px_rgba(37,42,48,.14)]',
        className,
      )}
    >
      {children}
    </section>
  );
}

export function PanelHead({ title, aside }: { title: ReactNode; aside?: ReactNode }) {
  return (
    <div className="mb-3.5 flex items-center justify-between gap-2.5">
      <h2 className="text-[15px] font-bold tracking-[-.005em]">{title}</h2>
      {aside}
    </div>
  );
}
