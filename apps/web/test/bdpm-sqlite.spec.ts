// Tests génération SQLite BDPM (#77).
import { mkdtempSync, statSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

import { medicamentsBdpm } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { generateBdpmSqlite } from '@/lib/bdpm/sqlite';

let env: TestDb;
let workDir: string;

beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.client`TRUNCATE TABLE medicaments_bdpm`;
  workDir = mkdtempSync(join(tmpdir(), 'piloo-bdpm-'));
});

afterEach(() => {
  rmSync(workDir, { recursive: true, force: true });
});

async function seedBdpm(rows: { cis: string; cip13?: string | null; version: string }[]) {
  await env.handle.db.insert(medicamentsBdpm).values(
    rows.map((r) => ({
      cis: r.cis,
      cip13: r.cip13 ?? null,
      cip7: null,
      denomination: `MEDOC ${r.cis}`,
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

describe('generateBdpmSqlite', () => {
  it('produit un fichier SQLite avec les tables et données attendues', async () => {
    await seedBdpm([
      { cis: '60000001', cip13: '3400934567890', version: '2026-04-01' },
      { cis: '60000002', cip13: '3400934567891', version: '2026-05-01' },
      { cis: '60000003', cip13: null, version: '2026-05-01' },
    ]);

    const out = join(workDir, 'bdpm.sqlite');
    const result = await generateBdpmSqlite(env.handle.db, out);

    expect(result.totalCis).toBe(3);
    expect(result.version).toBe('2026-05-01');

    const sqlite = new DatabaseSync(out, { readOnly: true });
    try {
      const meta = sqlite.prepare('SELECT key, value FROM bdpm_metadata ORDER BY key').all() as {
        key: string;
        value: string;
      }[];
      expect(meta.find((m) => m.key === 'version')?.value).toBe('2026-05-01');
      expect(meta.find((m) => m.key === 'total_cis')?.value).toBe('3');
      expect(meta.find((m) => m.key === 'generated_at')?.value).toMatch(/\d{4}-\d{2}-\d{2}T/);

      const meds = sqlite
        .prepare(
          'SELECT cis, cip13, denomination, taux_remboursement FROM medicaments ORDER BY cis',
        )
        .all();
      expect(meds).toHaveLength(3);
      expect(meds[0]).toMatchObject({
        cis: '60000001',
        cip13: '3400934567890',
        denomination: 'MEDOC 60000001',
        taux_remboursement: 65,
      });
    } finally {
      sqlite.close();
    }
  });

  it('lookup par CIP13 utilise un index (perf < 1 ms via prepared)', async () => {
    const rows = Array.from({ length: 5000 }, (_, i) => ({
      cis: String(60000000 + i),
      cip13: String(3400900000000 + i),
      version: '2026-05-01',
    }));
    await seedBdpm(rows);

    const out = join(workDir, 'bdpm.sqlite');
    await generateBdpmSqlite(env.handle.db, out);

    const sqlite = new DatabaseSync(out, { readOnly: true });
    try {
      // EXPLAIN doit montrer SEARCH USING INDEX idx_cip13.
      const plan = sqlite
        .prepare('EXPLAIN QUERY PLAN SELECT * FROM medicaments WHERE cip13 = ?')
        .all('3400900000123') as { detail: string }[];
      expect(plan.some((p) => p.detail.includes('idx_cip13'))).toBe(true);
    } finally {
      sqlite.close();
    }
  });

  it('table vide → SQLite valide avec total_cis=0 et version vide', async () => {
    const out = join(workDir, 'bdpm.sqlite');
    const result = await generateBdpmSqlite(env.handle.db, out);
    expect(result.totalCis).toBe(0);
    expect(result.version).toBeNull();
    const sqlite = new DatabaseSync(out, { readOnly: true });
    try {
      const total = sqlite.prepare('SELECT COUNT(*) AS n FROM medicaments').get() as { n: number };
      expect(total.n).toBe(0);
    } finally {
      sqlite.close();
    }
  });

  it('taille raisonnable : 5000 lignes → fichier < 2 Mo non compressé', async () => {
    const rows = Array.from({ length: 5000 }, (_, i) => ({
      cis: String(60000000 + i),
      cip13: String(3400900000000 + i),
      version: '2026-05-01',
    }));
    await seedBdpm(rows);
    const out = join(workDir, 'bdpm.sqlite');
    await generateBdpmSqlite(env.handle.db, out);
    const size = statSync(out).size;
    // 5000 lignes ~= 1.5 Mo non compressé. La vraie BDPM (14k lignes) ≈ 4 Mo,
    // gzip ramène à ~1 Mo, largement sous la limite 50 Mo de l'AC #77.
    expect(size).toBeLessThan(2 * 1024 * 1024);
  });
});
