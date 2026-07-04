// Pastille d'icône médicament teintée par forme galénique (redesign #370).
// Réutilisée dans les lignes d'inventaire, le drawer de détail et les rappels.
import { formeVisual, TINT_CLASSES } from '@/lib/medoc/forme';
import { cn } from '@/lib/utils';

export function MedIcon({
  forme,
  size = 42,
  className,
}: {
  forme: string | null | undefined;
  /** Côté de la pastille en px. */
  size?: number;
  className?: string;
}) {
  const { Icon, tint } = formeVisual(forme);
  // L'icône occupe ~52% de la pastille (ratio du redesign : 22 dans 42).
  const iconSize = Math.round(size * 0.52);
  return (
    <span
      className={cn('grid shrink-0 place-items-center rounded-xl', TINT_CLASSES[tint], className)}
      style={{ width: size, height: size, borderRadius: Math.round(size * 0.29) }}
    >
      <Icon size={iconSize} weight="fill" />
    </span>
  );
}
