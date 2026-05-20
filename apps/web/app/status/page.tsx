// Page publique /status (#148).
//
// Affiche l'état des composants Piloo : DB Postgres, BDPM, pipeline IA.
// Pas authentifié — utile pour debug à distance + lien public à partager
// si incident.
//
// Server Component (force-dynamic) qui appelle directement notre propre
// endpoint /api/status pour lire l'état.
export const dynamic = 'force-dynamic';
export const revalidate = 0;

interface ComponentStatus {
  name: string;
  status: 'ok' | 'degraded' | 'down';
  details?: string;
}

interface StatusResponse {
  status: 'ok' | 'degraded' | 'down';
  timestamp: string;
  components: ComponentStatus[];
}

async function fetchStatus(): Promise<StatusResponse> {
  // VERCEL_URL est l'URL de la deployment courante ; fallback localhost.
  const host =
    process.env['VERCEL_URL'] ?? process.env['NEXT_PUBLIC_BASE_URL'] ?? 'http://localhost:3000';
  const baseUrl = host.startsWith('http') ? host : `https://${host}`;
  const res = await fetch(`${baseUrl}/api/status`, { cache: 'no-store' });
  return (await res.json()) as StatusResponse;
}

const LABELS: Record<string, string> = {
  database: 'Base de données',
  bdpm: 'Base BDPM',
  ai_summaries: 'Résumés IA',
};

const STATUS_LABELS: Record<ComponentStatus['status'], string> = {
  ok: 'Opérationnel',
  degraded: 'Dégradé',
  down: 'Hors service',
};

const STATUS_DOT: Record<ComponentStatus['status'], string> = {
  ok: 'bg-piloo-success-on',
  degraded: 'bg-piloo-warning-on',
  down: 'bg-piloo-error-on',
};

export default async function StatusPage() {
  let data: StatusResponse;
  try {
    data = await fetchStatus();
  } catch {
    data = {
      status: 'down',
      timestamp: new Date().toISOString(),
      components: [
        {
          name: 'status',
          status: 'down',
          details: 'Endpoint /api/status injoignable.',
        },
      ],
    };
  }

  const ts = new Date(data.timestamp).toLocaleString('fr-FR', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });

  return (
    <main className="mx-auto max-w-2xl px-6 py-16">
      <header className="mb-10">
        <p className="text-sm text-muted-foreground">Piloo · Status</p>
        <h1 className="mt-1 font-display text-4xl">
          {data.status === 'ok' && 'Tout va bien'}
          {data.status === 'degraded' && 'Service partiellement dégradé'}
          {data.status === 'down' && 'Incident en cours'}
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">Dernière vérification : {ts}</p>
      </header>

      <ul className="space-y-3">
        {data.components.map((c) => (
          <li
            key={c.name}
            className="flex items-start gap-4 rounded-lg border border-border bg-piloo-surface p-4"
          >
            <span
              className={`mt-1.5 inline-block h-3 w-3 rounded-full ${STATUS_DOT[c.status]}`}
              aria-hidden
            />
            <div className="flex-1">
              <div className="flex items-baseline justify-between gap-2">
                <h2 className="font-semibold">{LABELS[c.name] ?? c.name}</h2>
                <span className="text-xs uppercase tracking-wide text-muted-foreground">
                  {STATUS_LABELS[c.status]}
                </span>
              </div>
              {c.details && <p className="mt-1 text-sm text-muted-foreground">{c.details}</p>}
            </div>
          </li>
        ))}
      </ul>

      <footer className="mt-10 text-xs text-muted-foreground">
        Page d&apos;état publique. Aucun token ou donnée nominative n&apos;est exposé. Pour signaler
        un incident :{' '}
        <a href="mailto:contact@piloo.fr" className="underline">
          contact@piloo.fr
        </a>
        .
      </footer>
    </main>
  );
}
