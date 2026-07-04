// Badge de statut (redesign #370). Pastille arrondie colorée par tonalité
// sémantique — réutilisée pour les statuts de boîte, de prise, d'alerte.
import type { ReactNode } from 'react';

import { cn } from '@/lib/utils';

export type BadgeTone = 'ok' | 'warn' | 'err' | 'info' | 'neutral';

const TONE_CLASSES: Record<BadgeTone, string> = {
  ok: 'bg-piloo-success text-piloo-success-on',
  warn: 'bg-piloo-warning text-piloo-warning-on',
  err: 'bg-piloo-error text-piloo-error-on',
  info: 'bg-[var(--piloo-color-info)] text-[var(--piloo-color-info-on)]',
  neutral: 'bg-piloo-surfaceSubtle text-[var(--piloo-color-text-secondary)]',
};

export function Badge({
  tone = 'neutral',
  children,
  className,
}: {
  tone?: BadgeTone;
  children: ReactNode;
  className?: string;
}) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-[5px] whitespace-nowrap rounded-full px-[9px] py-[3px] text-xs font-semibold',
        TONE_CLASSES[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}
