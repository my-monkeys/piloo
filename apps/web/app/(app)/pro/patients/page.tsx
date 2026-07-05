// Espace pro web : dashboard multi-patients (#150), harmonisé au système du
// redesign (#370) — une carte par officine accessible, avatar + rôle +
// tournée du jour + observance. Tap → active l'officine et va au dashboard.
'use client';

import { type components } from '@piloo/api-client';
import { $api } from '@piloo/api-client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';

import { Badge, type BadgeTone } from '@/components/app/badge';
import { officineAvatar, roleLabel, typeLabel } from '@/components/app/officine-display';
import { PageHeader } from '@/components/app/page-header';
import { Panel } from '@/components/app/panel';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

type Officine = components['schemas']['Officine'];

export default function ProPatientsPage() {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines');
  const items = data?.items ?? [];

  return (
    <>
      <PageHeader eyebrow="Changer d'officine" title="Officines" />

      {isLoading && <Muted>Chargement…</Muted>}
      {error && (
        <Panel>
          <Muted>Impossible de charger la liste des officines.</Muted>
        </Panel>
      )}
      {data && items.length === 0 && (
        <Panel>
          <p className="text-sm text-[var(--piloo-color-text-tertiary)]">
            Aucune officine liée à ton compte. Crée-en une ou fais-toi partager celle d&apos;un
            proche depuis{' '}
            <Link href="/settings/officines" className="text-piloo-primary underline">
              Réglages
            </Link>
            .
          </p>
        </Panel>
      )}
      {items.length > 0 && (
        <div className="grid gap-[18px] md:grid-cols-2 lg:grid-cols-3">
          {items.map((o) => (
            <PatientCard key={o.id} officine={o} />
          ))}
        </div>
      )}
    </>
  );
}

function PatientCard({ officine }: { officine: Officine }) {
  const router = useRouter();
  const { setActive } = useActiveOfficine();
  const prisesQ = $api.useQuery('get', '/v1/prises/today', {
    params: { query: { officine_id: officine.id } },
  });
  const boitesQ = $api.useQuery('get', '/v1/officines/{officineId}/boites', {
    params: { path: { officineId: officine.id } },
  });

  const prises = prisesQ.data?.items ?? [];
  const total = prises.length;
  const done = prises.filter((p) => p.statut === 'prise' || p.statut === 'sautee').length;
  const remaining = prises.filter((p) => p.statut === 'prevue').length;
  const missed = prises.filter((p) => p.statut === 'oubliee').length;
  const observance = total > 0 ? Math.round((done / total) * 100) : null;

  const boites = boitesQ.data?.items ?? [];
  const perimees = boites.filter((b) => b.statut === 'perimee').length;

  const avatar = officineAvatar(officine.type);
  const roleTone: BadgeTone =
    officine.role === 'owner' ? 'ok' : officine.role === 'editor' ? 'info' : 'neutral';

  return (
    <button
      type="button"
      onClick={() => {
        setActive(officine.id);
        router.push('/dashboard');
      }}
      className="flex flex-col gap-3.5 rounded-2xl border border-[var(--piloo-color-border-soft,var(--piloo-color-border))] bg-piloo-surface p-5 text-left shadow-[0_1px_2px_rgba(37,42,48,.03),0_10px_26px_-18px_rgba(37,42,48,.14)] transition-colors hover:bg-piloo-surfaceSubtle"
    >
      <div className="flex items-center gap-[11px]">
        <span
          className={cn(
            'grid h-[38px] w-[38px] shrink-0 place-items-center rounded-[10px]',
            avatar.cls,
          )}
        >
          <avatar.Icon size={19} weight="fill" />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate font-display text-lg font-medium">{officine.nom}</span>
          <span className="block text-[12px] text-[var(--piloo-color-text-tertiary)]">
            {typeLabel(officine.type)}
          </span>
        </span>
        <Badge tone={roleTone}>{roleLabel(officine.role)}</Badge>
      </div>

      <div className="flex flex-col gap-2 border-t border-[var(--piloo-color-border-soft,var(--piloo-color-border))] pt-3.5 text-[13px]">
        <Row
          label="Boîtes"
          value={
            perimees > 0
              ? `${String(boites.length)} · ${String(perimees)} périmée${perimees > 1 ? 's' : ''}`
              : String(boites.length)
          }
        />
        <Row
          label="Prises du jour"
          value={
            total === 0
              ? '—'
              : remaining > 0
                ? `${String(done)}/${String(total)} · ${String(remaining)} restantes`
                : `${String(done)}/${String(total)}`
          }
        />
        {missed > 0 && (
          <Row
            label="Oubliées"
            value={String(missed)}
            valueClass="font-semibold text-piloo-error-on"
          />
        )}
        {observance !== null && (
          <div className="mt-0.5 flex items-center justify-between">
            <span className="text-[var(--piloo-color-text-secondary)]">Observance jour</span>
            <Badge tone={observance >= 80 ? 'ok' : observance >= 50 ? 'warn' : 'err'}>
              {observance}%
            </Badge>
          </div>
        )}
      </div>
    </button>
  );
}

function Row({ label, value, valueClass }: { label: string; value: string; valueClass?: string }) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-[var(--piloo-color-text-secondary)]">{label}</span>
      <span className={cn('truncate text-right font-semibold', valueClass)}>{value}</span>
    </div>
  );
}

function Muted({ children }: { children: React.ReactNode }) {
  return <p className="text-sm text-[var(--piloo-color-text-tertiary)]">{children}</p>;
}
