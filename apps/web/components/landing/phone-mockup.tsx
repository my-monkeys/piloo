// Mockup téléphone « Mon pilulier » de la section spotlight (#394).
// Écran illustratif : prises rangées par moment de la journée, anneau de
// progression, chip de rappel flottante. Données fictives.
import {
  BatteryFullIcon as BatteryFull,
  BellRingingIcon as BellRinging,
  CellSignalFullIcon as CellSignalFull,
  CheckIcon as Check,
  CloudMoonIcon as CloudMoon,
  MoonStarsIcon as MoonStars,
  SunIcon as Sun,
  SunHorizonIcon as SunHorizon,
  WifiHighIcon as WifiHigh,
} from '@phosphor-icons/react/dist/ssr';
import type { Icon } from '@phosphor-icons/react';

interface PilItem {
  name: string;
  qty: string;
  done: boolean;
  tag?: string;
}

interface PilCard {
  icon: Icon;
  label: string;
  time: string;
  items: PilItem[];
}

const PILULIER: PilCard[] = [
  {
    icon: SunHorizon,
    label: 'Matin',
    time: '08:00',
    items: [{ name: 'Levothyrox 100 µg', qty: '1 comprimé · à jeun', done: true }],
  },
  {
    icon: Sun,
    label: 'Midi',
    time: '12:30',
    items: [
      { name: 'Doliprane 1000 mg', qty: '1 comprimé', done: false },
      { name: 'Amoxicilline 500 mg', qty: '1 gélule', done: false },
    ],
  },
  {
    icon: CloudMoon,
    label: 'Soir',
    time: '19:00',
    items: [{ name: 'Kardégic 75 mg', qty: '1 sachet', done: true }],
  },
  {
    icon: MoonStars,
    label: 'Coucher',
    time: '21:00',
    items: [{ name: 'Ozempic 1 mg', qty: '1 injection', done: false, tag: 'hebdo' }],
  },
];

export function PhoneMockup() {
  return (
    <div className="relative mx-auto w-[300px] animate-rise">
      <div className="absolute -top-4 -left-5 z-10 flex animate-float-a items-center gap-2 whitespace-nowrap rounded-[14px] border border-piloo-surfaceSubtle bg-piloo-surface px-[15px] py-[11px] text-[13.5px] font-semibold text-piloo-primary-hover shadow-[0_12px_30px_-12px_rgba(37,42,48,0.3)]">
        <BellRinging size={19} weight="fill" className="text-piloo-primary" />
        Rappel · Doliprane à 12:30
      </div>
      <div className="relative rounded-[46px] bg-[#1e2226] p-[11px] shadow-[0_44px_84px_-34px_rgba(37,42,48,0.5),0_0_0_1px_rgba(37,42,48,0.08)]">
        <div className="absolute left-1/2 top-[11px] z-[5] h-6 w-28 -translate-x-1/2 rounded-b-[15px] bg-[#1e2226]" />
        <div className="relative overflow-hidden rounded-[36px] bg-piloo-background">
          <div className="flex items-center justify-between px-6 pb-1 pt-[13px] text-[12.5px] font-bold text-foreground">
            <span>9:41</span>
            <span className="inline-flex items-center gap-[5px]">
              <CellSignalFull size={14} weight="fill" />
              <WifiHigh size={14} weight="fill" />
              <BatteryFull size={14} weight="fill" />
            </span>
          </div>
          <div className="px-[15px] pb-5 pt-2">
            <div className="flex items-center justify-between px-1 pb-[15px] pt-2">
              <div>
                <div className="text-base font-bold tracking-tight">Mon pilulier</div>
                <div className="mt-px text-[11.5px] font-semibold text-muted-foreground">
                  Aujourd’hui · Sam. 4 juil.
                </div>
              </div>
              <div className="grid size-[46px] shrink-0 place-items-center rounded-full bg-[conic-gradient(var(--piloo-color-primary)_216deg,var(--piloo-color-surface-subtle)_0)]">
                <span className="grid size-9 place-items-center rounded-full bg-piloo-surface text-[11.5px] font-bold text-foreground">
                  3/5
                </span>
              </div>
            </div>
            {PILULIER.map((c) => (
              <div
                key={c.label}
                className="mb-2.5 rounded-xl border border-piloo-surfaceSubtle bg-piloo-surface px-[13px] py-3 shadow-[0_1px_2px_rgba(37,42,48,0.03)]"
              >
                <div className="mb-2 flex items-center gap-2">
                  <c.icon size={16} className="text-muted-foreground" />
                  <span className="text-[12.5px] font-bold">{c.label}</span>
                  <span className="ml-auto text-[11px] font-semibold tabular-nums text-muted-foreground">
                    {c.time}
                  </span>
                </div>
                <div className="flex flex-col gap-[3px]">
                  {c.items.map((it) => (
                    <div key={it.name} className="flex items-center gap-[11px] py-1.5">
                      <span
                        className={`grid size-[22px] shrink-0 place-items-center rounded-[7px] border-2 ${
                          it.done
                            ? 'border-piloo-primary bg-piloo-primary text-white'
                            : 'border-border text-transparent'
                        }`}
                      >
                        <Check size={12} />
                      </span>
                      <span className="flex min-w-0 flex-1 flex-col">
                        <span
                          className={`truncate text-[13px] font-semibold ${
                            it.done ? 'text-muted-foreground' : 'text-foreground'
                          }`}
                        >
                          {it.name}
                        </span>
                        <span className="mt-px text-[11px] text-muted-foreground">{it.qty}</span>
                      </span>
                      {it.tag ? (
                        <span className="shrink-0 rounded-full bg-piloo-accent-soft px-[7px] py-0.5 text-[10px] font-bold text-piloo-accent">
                          {it.tag}
                        </span>
                      ) : null}
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
