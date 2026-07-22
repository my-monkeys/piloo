// Boutons stores de la landing (#394) : App Store réel + Google Play
// annoncé « Bientôt » (l'app Android n'est pas publiée sur le Play Store).
// Deux variantes : `dark` sur fond clair (hero), `light` sur la bande CTA
// verte.
import {
  AppleLogoIcon as AppleLogo,
  GooglePlayLogoIcon as GooglePlayLogo,
} from '@phosphor-icons/react/dist/ssr';

export const APP_STORE_URL = 'https://apps.apple.com/fr/app/piloo/id6767163944';

export function StoreButtons({ variant = 'dark' }: { variant?: 'dark' | 'light' }) {
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
    <div className="flex flex-wrap items-center justify-center gap-3 lg:justify-start">
      <a
        href={APP_STORE_URL}
        className={`inline-flex min-w-[214px] items-center gap-3 rounded-[14px] py-[11px] pl-[17px] pr-5 transition hover:-translate-y-px ${appStoreCls}`}
      >
        <AppleLogo size={29} weight="fill" />
        <span className="flex flex-col text-left leading-[1.12]">
          <span className="text-[10.5px] font-semibold tracking-wide opacity-80">
            Télécharger dans
          </span>
          <span className="text-[16.5px] font-bold tracking-tight">l’App Store</span>
        </span>
      </a>
      <div
        className={`relative inline-flex min-w-[214px] cursor-default items-center gap-3 rounded-[14px] py-[11px] pl-[17px] pr-5 ${soonCls}`}
      >
        <GooglePlayLogo size={29} weight="fill" className="opacity-70" />
        <span className="flex flex-col text-left leading-[1.12]">
          <span className="text-[10.5px] font-semibold tracking-wide opacity-80">Bientôt sur</span>
          <span className="text-[16.5px] font-bold tracking-tight">Google Play</span>
        </span>
        <span
          className={`absolute -right-1.5 -top-[9px] rounded-full border-2 px-[9px] py-0.5 text-[11px] font-bold shadow-[0_2px_6px_rgba(37,42,48,0.16)] ${soonBadgeCls}`}
        >
          Bientôt
        </span>
      </div>
    </div>
  );
}
