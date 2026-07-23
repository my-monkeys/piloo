// Boutons stores de la landing (#394) : App Store réel + Google Play
// annoncé « Bientôt » (l'app Android n'est pas publiée sur le Play Store).
// Deux variantes : `dark` sur fond clair (hero), `light` sur la bande CTA
// verte.
import {
  AppleLogoIcon as AppleLogo,
  GooglePlayLogoIcon as GooglePlayLogo,
} from '@phosphor-icons/react/dist/ssr';

export const APP_STORE_URL = 'https://apps.apple.com/fr/app/piloo/id6767163944';

export function StoreButtons({
  variant = 'dark',
  align = 'start',
}: {
  variant?: 'dark' | 'light';
  /** `start` : centré en mobile, aligné à gauche en desktop (hero).
   *  `center` : toujours centré (bande CTA). */
  align?: 'start' | 'center';
}) {
  const appStoreCls =
    variant === 'dark'
      ? 'bg-foreground text-white hover:bg-[#1b1f24] hover:shadow-[0_10px_24px_-10px_rgba(37,42,48,0.45)]'
      : 'bg-white text-foreground hover:bg-[#f2efe8]';
  const soonCls =
    variant === 'dark'
      ? 'border border-border bg-piloo-surface text-muted-foreground'
      : 'border border-white/30 bg-white/15 text-white/80';
  const soonBadgeCls =
    variant === 'dark'
      ? 'bg-piloo-accent-soft text-piloo-accent border-piloo-background'
      : 'bg-white/95 text-piloo-primary-hover border-piloo-primary';

  return (
    <div
      className={`flex flex-wrap items-center justify-center gap-2.5 sm:gap-3 ${
        align === 'start' ? 'lg:justify-start' : ''
      }`}
    >
      {/* En mobile : compacts + flex-1 pour tenir à deux sur la ligne. */}
      <a
        href={APP_STORE_URL}
        className={`inline-flex flex-1 items-center justify-center gap-2.5 rounded-[14px] px-3 py-[9px] transition hover:-translate-y-px sm:min-w-[214px] sm:flex-none sm:justify-start sm:gap-3 sm:py-[11px] sm:pl-[17px] sm:pr-5 ${appStoreCls}`}
      >
        <AppleLogo size={29} weight="fill" className="size-6 shrink-0 sm:size-[29px]" />
        <span className="flex flex-col text-left leading-[1.12]">
          <span className="whitespace-nowrap text-[10px] font-semibold tracking-wide opacity-80 sm:text-[10.5px]">
            Télécharger dans
          </span>
          <span className="whitespace-nowrap text-[15px] font-bold tracking-tight sm:text-[16.5px]">
            l’App Store
          </span>
        </span>
      </a>
      <div
        className={`relative inline-flex flex-1 cursor-default items-center justify-center gap-2.5 rounded-[14px] px-3 py-[9px] sm:min-w-[214px] sm:flex-none sm:justify-start sm:gap-3 sm:py-[11px] sm:pl-[17px] sm:pr-5 ${soonCls}`}
      >
        <GooglePlayLogo
          size={29}
          weight="fill"
          className="size-6 shrink-0 opacity-70 sm:size-[29px]"
        />
        <span className="flex flex-col text-left leading-[1.12]">
          <span className="whitespace-nowrap text-[10px] font-semibold tracking-wide opacity-80 sm:text-[10.5px]">
            Bientôt sur
          </span>
          <span className="whitespace-nowrap text-[15px] font-bold tracking-tight sm:text-[16.5px]">
            Google Play
          </span>
        </span>
        <span
          className={`absolute -right-1.5 -top-[9px] z-10 rounded-full border-2 px-[9px] py-0.5 text-[11px] font-bold shadow-[0_2px_6px_rgba(37,42,48,0.16)] ${soonBadgeCls}`}
        >
          Bientôt
        </span>
      </div>
    </div>
  );
}
