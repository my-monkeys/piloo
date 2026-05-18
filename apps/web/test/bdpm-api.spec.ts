// Tests d'intégration /api/v1/bdpm/{version,diff} (#76).
import { medicamentsBdpm } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
  vi.doMock('@/lib/db', () => ({ getDb: () => env.handle.db }));
}, 90_000);

afterAll(async () => {
  vi.doUnmock('@/lib/db');
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.client`TRUNCATE TABLE medicaments_bdpm`;
});

async function importHandlers() {
  return {
    version: await import('@/app/api/v1/bdpm/version/route'),
    diff: await import('@/app/api/v1/bdpm/diff/route'),
    search: await import('@/app/api/v1/bdpm/search/route'),
  };
}

async function seed(
  rows: { cis: string; cip13?: string; version: string; denomination?: string }[],
) {
  await env.handle.db.insert(medicamentsBdpm).values(
    rows.map((r) => ({
      cis: r.cis,
      cip13: r.cip13 ?? null,
      cip7: null,
      denomination: r.denomination ?? `MEDOC ${r.cis}`,
      forme: 'comprimé',
      dosage: '500 mg',
      voieAdministration: 'orale',
      titulaire: 'EDITEUR',
      statutAmm: 'Autorisation active',
      tauxRemboursement: 65,
      versionBdpm: r.version,
    })),
  );
}

describe('GET /api/v1/bdpm/version', () => {
  it('retourne version + total quand la base est peuplée', async () => {
    await seed([
      { cis: '60000001', version: '2026-04-01' },
      { cis: '60000002', version: '2026-05-01' },
      { cis: '60000003', version: '2026-05-01' },
    ]);
    const { version } = await importHandlers();
    const res = await version.GET();
    expect(res.status).toBe(200);
    const body = (await res.json()) as { version: string; total_cis: number };
    expect(body.version).toBe('2026-05-01');
    expect(body.total_cis).toBe(3);
  });

  it('retourne {version: null, total_cis: 0} quand la base est vide', async () => {
    const { version } = await importHandlers();
    const res = await version.GET();
    const body = (await res.json()) as { version: string | null; total_cis: number };
    expect(body.version).toBeNull();
    expect(body.total_cis).toBe(0);
  });
});

describe('GET /api/v1/bdpm/diff', () => {
  it('retourne uniquement les médicaments avec version > from', async () => {
    await seed([
      { cis: '60000001', version: '2026-03-01', denomination: 'OLD' },
      { cis: '60000002', version: '2026-04-15', denomination: 'MID' },
      { cis: '60000003', version: '2026-05-01', denomination: 'NEW' },
    ]);
    const { diff } = await importHandlers();
    const res = await diff.GET(new Request('http://x/api/v1/bdpm/diff?from=2026-04-01'));
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      from: string;
      current: string;
      items: { cis: string; denomination: string }[];
    };
    expect(body.from).toBe('2026-04-01');
    expect(body.current).toBe('2026-05-01');
    expect(body.items.map((i) => i.cis)).toEqual(['60000002', '60000003']);
  });

  it('from = current version → items vide', async () => {
    await seed([
      { cis: '60000001', version: '2026-05-01' },
      { cis: '60000002', version: '2026-05-01' },
    ]);
    const { diff } = await importHandlers();
    const res = await diff.GET(new Request('http://x/api/v1/bdpm/diff?from=2026-05-01'));
    const body = (await res.json()) as { items: unknown[] };
    expect(body.items).toHaveLength(0);
  });

  it('400 si from manquant', async () => {
    const { diff } = await importHandlers();
    const res = await diff.GET(new Request('http://x/api/v1/bdpm/diff'));
    expect(res.status).toBe(400);
  });

  it('400 si from au mauvais format', async () => {
    const { diff } = await importHandlers();
    const res = await diff.GET(new Request('http://x/api/v1/bdpm/diff?from=2026-99-99'));
    expect(res.status).toBe(400);
  });

  it('items contient tous les champs sérialisés en snake_case', async () => {
    await seed([{ cis: '60000001', cip13: '3400934567890', version: '2026-05-01' }]);
    const { diff } = await importHandlers();
    const res = await diff.GET(new Request('http://x/api/v1/bdpm/diff?from=2026-04-01'));
    const body = (await res.json()) as { items: Record<string, unknown>[] };
    expect(body.items[0]).toMatchObject({
      cis: '60000001',
      cip13: '3400934567890',
      voie_administration: 'orale',
      taux_remboursement: 65,
      version_bdpm: '2026-05-01',
    });
  });

  it('endpoints publics : pas de 401 sans credential', async () => {
    const { version, diff } = await importHandlers();
    const v = await version.GET();
    const d = await diff.GET(new Request('http://x/api/v1/bdpm/diff?from=2026-01-01'));
    expect(v.status).toBe(200);
    expect(d.status).toBe(200);
  });
});

describe('GET /api/v1/bdpm/search', () => {
  it('400 si q absent', async () => {
    const { search } = await importHandlers();
    const res = await search.GET(new Request('http://x/api/v1/bdpm/search'));
    expect(res.status).toBe(400);
  });

  it('400 si q < 2 caractères', async () => {
    const { search } = await importHandlers();
    const res = await search.GET(new Request('http://x/api/v1/bdpm/search?q=a'));
    expect(res.status).toBe(400);
  });

  it('CIP13 exact → match unique', async () => {
    await seed([
      { cis: '60000001', cip13: '3400934567890', version: '2026-05-01', denomination: 'A' },
      { cis: '60000002', cip13: '3400934567891', version: '2026-05-01', denomination: 'B' },
    ]);
    const { search } = await importHandlers();
    const res = await search.GET(new Request('http://x/api/v1/bdpm/search?q=3400934567890'));
    const body = (await res.json()) as { items: { cis: string }[] };
    expect(body.items.map((i) => i.cis)).toEqual(['60000001']);
  });

  it('recherche par nom : préfixe avant contains', async () => {
    await seed([
      { cis: '60000001', version: '2026-05-01', denomination: 'DOLIPRANE 500MG' },
      { cis: '60000002', version: '2026-05-01', denomination: 'PARACETAMOL DOLIPRANE' },
      { cis: '60000003', version: '2026-05-01', denomination: 'IBUPROFENE' },
    ]);
    const { search } = await importHandlers();
    const res = await search.GET(new Request('http://x/api/v1/bdpm/search?q=DOLIPRANE'));
    const body = (await res.json()) as { items: { cis: string; denomination: string }[] };
    expect(body.items.map((i) => i.denomination)).toEqual([
      'DOLIPRANE 500MG',
      'PARACETAMOL DOLIPRANE',
    ]);
  });

  it('recherche insensible à la casse', async () => {
    await seed([{ cis: '60000001', version: '2026-05-01', denomination: 'DOLIPRANE 500MG' }]);
    const { search } = await importHandlers();
    const res = await search.GET(new Request('http://x/api/v1/bdpm/search?q=doli'));
    const body = (await res.json()) as { items: unknown[] };
    expect(body.items).toHaveLength(1);
  });

  it('limite à 20 résultats', async () => {
    await seed(
      Array.from({ length: 30 }, (_, i) => ({
        cis: `7000000${i.toString().padStart(2, '0')}`,
        version: '2026-05-01',
        denomination: `MEDOC TEST ${String(i)}`,
      })),
    );
    const { search } = await importHandlers();
    const res = await search.GET(new Request('http://x/api/v1/bdpm/search?q=MEDOC'));
    const body = (await res.json()) as { items: unknown[] };
    expect(body.items.length).toBeLessThanOrEqual(20);
  });

  it('public : pas de 401 sans credential', async () => {
    const { search } = await importHandlers();
    const res = await search.GET(new Request('http://x/api/v1/bdpm/search?q=test'));
    expect(res.status).toBe(200);
  });
});
