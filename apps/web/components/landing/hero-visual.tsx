// Visuel du hero de la landing (#394) : carte « Aujourd'hui » (extrait de
// la timeline) + deux chips flottantes (alerte péremption, prise cochée).
// Données d'illustration fictives — aucune donnée utilisateur.
import {
  CheckIcon as Check,
  PillIcon as Pill,
  SyringeIcon as Syringe,
  WarningCircleIcon as WarningCircle,
} from '@phosphor-icons/react/dist/ssr';

const DOSES = [
  { icon: Pill, tint: 'oral', name: 'Levothyrox 100 µg', status: 'Prise', done: true },
  { icon: Pill, tint: 'oral', name: 'Doliprane 1000 mg', status: '12:30', done: false },
  { icon: Syringe, tint: 'inj', name: 'Ozempic 1 mg', status: '21:00', done: false },
] as const;

const CHIP_CLS =
  'absolute flex items-center gap-2 rounded-[14px] border border-piloo-surfaceSubtle bg-piloo-surface px-[15px] py-[11px] text-[13.5px] font-semibold shadow-[0_12px_30px_-12px_rgba(37,42,48,0.3)] whitespace-nowrap max-sm:scale-90';

export function HeroVisual() {
  return (
    <div className="relative w-full max-w-[420px] animate-rise justify-self-center [animation-delay:0.2s]">
      <div className="rounded-[22px] border border-piloo-surfaceSubtle bg-piloo-surface p-[22px] shadow-[0_2px_4px_rgba(37,42,48,0.04),0_30px_60px_-28px_rgba(37,42,48,0.32)]">
        <div className="mb-4 flex items-center justify-between">
          <span className="text-[17px] font-bold tracking-tight">Aujourd’hui</span>
          <span className="text-[12.5px] font-semibold text-muted-foreground">
            Samedi 4 juillet
          </span>
        </div>
        <ul className="flex flex-col">
          {DOSES.map((d) => (
            <li
              key={d.name}
              className="flex items-center gap-3 border-t border-piloo-surfaceSubtle px-0.5 py-3 first:border-t-0"
            >
              <span
                className={`grid size-[38px] shrink-0 place-items-center rounded-[11px] ${
                  d.tint === 'oral'
                    ? 'bg-piloo-primary-soft text-piloo-primary-hover'
                    : 'bg-piloo-accent-soft text-piloo-accent'
                }`}
              >
                <d.icon size={20} />
              </span>
              <span className="min-w-0 flex-1 truncate text-[14.5px] font-semibold">{d.name}</span>
              <span
                className={`text-[11.5px] font-semibold ${
                  d.done ? 'text-piloo-success-on' : 'text-muted-foreground'
                }`}
              >
                {d.status}
              </span>
            </li>
          ))}
        </ul>
      </div>
      <div className={`${CHIP_CLS} -top-[22px] right-[-14px] animate-float-a text-piloo-error-on`}>
        <WarningCircle size={19} weight="fill" />
        Amoxicilline périme dans 16 j
      </div>
      <div className={`${CHIP_CLS} -bottom-5 -left-5 animate-float-b text-piloo-success-on`}>
        <span className="grid size-[26px] place-items-center rounded-lg bg-piloo-success">
          <Check size={16} />
        </span>
        Kardégic · pris ce soir
      </div>
    </div>
  );
}
