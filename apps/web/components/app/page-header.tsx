// En-tête de page (redesign #370). Eyebrow (sur-titre discret) + titre serif
// + action optionnelle à droite. Présent sur toutes les pages de l'app.
import type { ReactNode } from 'react';

export function PageHeader({
  eyebrow,
  title,
  action,
}: {
  eyebrow?: ReactNode;
  title: ReactNode;
  action?: ReactNode;
}) {
  return (
    <header className="mb-[26px] flex flex-col items-start justify-between gap-3.5 sm:flex-row sm:items-end">
      <div>
        {eyebrow && (
          <p className="mb-[5px] text-[12.5px] font-semibold text-[var(--piloo-color-text-tertiary)]">
            {eyebrow}
          </p>
        )}
        <h1 className="font-display text-[26px] font-medium leading-tight tracking-[-.015em] sm:text-[30px]">
          {title}
        </h1>
      </div>
      {action}
    </header>
  );
}
