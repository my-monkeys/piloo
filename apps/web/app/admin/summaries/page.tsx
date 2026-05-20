// Admin UI résumés IA (#166).
//
// Page protégée — l'API /api/v1/admin/summaries renvoie 403 si l'user
// n'est pas dans ADMIN_EMAILS. Permet de browser, filtrer (manquants
// vs définis), chercher par dénomination, éditer le résumé inline, ou
// le reset (la prochaine passe pipeline le re-générera).
'use client';

import { useEffect, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';

interface Item {
  cip13: string;
  denomination: string;
  dosage: string | null;
  forme: string | null;
  titulaire: string | null;
  aiSummary: string | null;
  aiSummaryVersion: string | null;
}

interface ListResponse {
  items: Item[];
  total: number;
  with_summary: number;
}

type Filter = 'all' | 'missing' | 'set';

const PAGE_SIZE = 50;

export default function AdminSummariesPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [total, setTotal] = useState(0);
  const [withSummary, setWithSummary] = useState(0);
  const [filter, setFilter] = useState<Filter>('all');
  const [query, setQuery] = useState('');
  const [offset, setOffset] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const params = new URLSearchParams();
        if (query.trim().length > 0) params.set('q', query.trim());
        if (filter === 'missing') params.set('only', 'missing');
        if (filter === 'set') params.set('only', 'set');
        params.set('limit', String(PAGE_SIZE));
        params.set('offset', String(offset));
        const res = await fetch(`/api/v1/admin/summaries?${params.toString()}`);
        if (!res.ok) {
          throw new Error(`HTTP ${String(res.status)}`);
        }
        const data = (await res.json()) as ListResponse;
        if (cancelled) return;
        setItems(data.items);
        setTotal(data.total);
        setWithSummary(data.with_summary);
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : 'Erreur');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [filter, query, offset]);

  async function save(cip13: string, ai_summary: string): Promise<void> {
    const res = await fetch(`/api/v1/admin/summaries/${cip13}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ai_summary }),
    });
    if (!res.ok) throw new Error(`Save failed: HTTP ${String(res.status)}`);
    setItems((prev) =>
      prev.map((i) =>
        i.cip13 === cip13 ? { ...i, aiSummary: ai_summary, aiSummaryVersion: 'manual' } : i,
      ),
    );
  }

  async function reset(cip13: string): Promise<void> {
    if (!confirm('Reset le résumé ? Il sera re-généré au prochain run.')) return;
    const res = await fetch(`/api/v1/admin/summaries/${cip13}`, { method: 'DELETE' });
    if (!res.ok) throw new Error(`Delete failed: HTTP ${String(res.status)}`);
    setItems((prev) =>
      prev.map((i) => (i.cip13 === cip13 ? { ...i, aiSummary: null, aiSummaryVersion: null } : i)),
    );
  }

  const pct = total > 0 ? Math.round((withSummary / total) * 100) : 0;

  return (
    <main className="mx-auto max-w-5xl px-6 py-10">
      <header className="mb-6">
        <h1 className="font-display text-3xl">Résumés IA — admin</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {withSummary} / {total} résumés générés ({pct}%)
        </p>
      </header>

      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center">
        <Input
          type="search"
          placeholder="Rechercher par dénomination…"
          value={query}
          onChange={(e) => {
            setOffset(0);
            setQuery(e.target.value);
          }}
          className="sm:w-80"
        />
        <div className="flex gap-2">
          {(['all', 'missing', 'set'] as const).map((f) => (
            <Button
              key={f}
              size="sm"
              variant={filter === f ? 'default' : 'outline'}
              onClick={() => {
                setOffset(0);
                setFilter(f);
              }}
            >
              {f === 'all' ? 'Tous' : f === 'missing' ? 'Manquants' : 'Définis'}
            </Button>
          ))}
        </div>
      </div>

      {error && (
        <p className="mb-4 text-sm text-piloo-error-on">
          Erreur : {error} — assure-toi d&apos;être connecté avec un compte admin.
        </p>
      )}
      {loading && <p className="text-sm text-muted-foreground">Chargement…</p>}

      <div className="space-y-3">
        {items.map((item) => (
          <SummaryRow key={item.cip13} item={item} onSave={save} onReset={reset} />
        ))}
      </div>

      {!loading && items.length > 0 && (
        <div className="mt-6 flex items-center justify-between text-sm">
          <Button
            size="sm"
            variant="outline"
            disabled={offset === 0}
            onClick={() => {
              setOffset(Math.max(0, offset - PAGE_SIZE));
            }}
          >
            ← Précédent
          </Button>
          <span className="text-muted-foreground">
            {offset + 1} – {offset + items.length}
          </span>
          <Button
            size="sm"
            variant="outline"
            disabled={items.length < PAGE_SIZE}
            onClick={() => {
              setOffset(offset + PAGE_SIZE);
            }}
          >
            Suivant →
          </Button>
        </div>
      )}
    </main>
  );
}

function SummaryRow({
  item,
  onSave,
  onReset,
}: {
  item: Item;
  onSave: (cip13: string, ai_summary: string) => Promise<void>;
  onReset: (cip13: string) => Promise<void>;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(item.aiSummary ?? '');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  function startEdit() {
    setDraft(item.aiSummary ?? '');
    setEditing(true);
    setErr(null);
  }

  async function commit() {
    setBusy(true);
    setErr(null);
    try {
      await onSave(item.cip13, draft.trim());
      setEditing(false);
    } catch (e) {
      setErr(e instanceof Error ? e.message : 'Erreur');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-baseline justify-between gap-3">
          <CardTitle className="text-base">{item.denomination}</CardTitle>
          <span className="text-xs text-muted-foreground">{item.cip13}</span>
        </div>
        <p className="text-xs text-muted-foreground">
          {[item.titulaire, item.forme, item.dosage].filter(Boolean).join(' · ')}
        </p>
      </CardHeader>
      <CardContent>
        {editing ? (
          <>
            <textarea
              value={draft}
              onChange={(e) => {
                setDraft(e.target.value);
              }}
              rows={4}
              className="w-full rounded-md border border-border bg-white p-2 text-sm"
              placeholder="2 phrases max — à quoi ça sert + précaution générale"
            />
            {err && <p className="mt-1 text-xs text-piloo-error-on">{err}</p>}
            <div className="mt-2 flex gap-2">
              <Button
                size="sm"
                onClick={() => {
                  void commit();
                }}
                disabled={busy}
              >
                {busy ? 'Enregistrement…' : 'Enregistrer'}
              </Button>
              <Button
                size="sm"
                variant="outline"
                onClick={() => {
                  setEditing(false);
                }}
              >
                Annuler
              </Button>
            </div>
          </>
        ) : (
          <>
            {item.aiSummary ? (
              <p className="text-sm">{item.aiSummary}</p>
            ) : (
              <p className="text-sm italic text-muted-foreground">Pas encore de résumé.</p>
            )}
            <div className="mt-2 flex items-center justify-between gap-2">
              <span className="text-xs text-muted-foreground">{item.aiSummaryVersion ?? '—'}</span>
              <div className="flex gap-2">
                <Button size="sm" variant="outline" onClick={startEdit}>
                  {item.aiSummary ? 'Éditer' : 'Rédiger'}
                </Button>
                {item.aiSummary && (
                  <Button size="sm" variant="outline" onClick={() => void onReset(item.cip13)}>
                    Reset
                  </Button>
                )}
              </div>
            </div>
          </>
        )}
      </CardContent>
    </Card>
  );
}
