// Tests d'intégration import BDPM (#75).
//
// Couverture :
//  - import depuis fixture → bonne ligne en DB
//  - re-import même version → UPSERT sans duplicat (PK=cis)
//  - re-import nouvelle version → champs mis à jour
//  - performance : un dataset synthétique de 5000 lignes < 5s
import { medicamentsBdpm } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { importBdpm } from '@/lib/bdpm/import';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.client`TRUNCATE TABLE medicaments_bdpm`;
});

const CIS_FIXTURE = [
  '60002283\tDOLIPRANE 1000 mg, comprimé pelliculé\tcomprimé pelliculé\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t01/01/1995\t\t\tSANOFI AVENTIS FRANCE\tNon',
  '64014219\tDAFALGAN 500 mg, gélule\tgélule\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t15/06/1998\t\t\tUPSA\tNon',
].join('\n');

const CIP_FIXTURE = [
  '60002283\t3400934567890\tplaquette de 8\tPrésentation active\tDéclaration\t01/01/1995\t3400934567890\toui\t65%\t2,18\t2,18\t',
  '64014219\t3400935123456\tplaquette de 16\tPrésentation active\tDéclaration\t15/06/1998\t3400935123456\toui\t65%\t1,80\t1,80\t',
].join('\n');

describe('importBdpm', () => {
  it('insère 2 lignes depuis la fixture', async () => {
    const result = await importBdpm(env.handle.db, {
      cisContent: CIS_FIXTURE,
      cipContent: CIP_FIXTURE,
      versionBdpm: '2026-05-01',
    });
    expect(result.cisCount).toBe(2);
    expect(result.cipCount).toBe(2);
    expect(result.rowsInserted).toBe(2);

    const rows = await env.handle.db.select().from(medicamentsBdpm);
    expect(rows).toHaveLength(2);
    const doli = rows.find((r) => r.cis === '60002283')!;
    expect(doli).toMatchObject({
      cip13: '3400934567890',
      denomination: 'DOLIPRANE 1000 mg, comprimé pelliculé',
      dosage: '1000 mg',
      tauxRemboursement: 65,
      versionBdpm: '2026-05-01',
    });
  });

  it('UPSERT : ré-import même version ne duplique pas, conserve PK', async () => {
    await importBdpm(env.handle.db, {
      cisContent: CIS_FIXTURE,
      cipContent: CIP_FIXTURE,
      versionBdpm: '2026-05-01',
    });
    await importBdpm(env.handle.db, {
      cisContent: CIS_FIXTURE,
      cipContent: CIP_FIXTURE,
      versionBdpm: '2026-05-01',
    });
    const rows = await env.handle.db.select().from(medicamentsBdpm);
    expect(rows).toHaveLength(2);
  });

  it('UPSERT : nouvelle version → tauxRemboursement et versionBdpm mis à jour', async () => {
    await importBdpm(env.handle.db, {
      cisContent: CIS_FIXTURE,
      cipContent: CIP_FIXTURE,
      versionBdpm: '2026-05-01',
    });
    const cipUpdated = CIP_FIXTURE.replace('65%\t2,18', '30%\t2,18');
    await importBdpm(env.handle.db, {
      cisContent: CIS_FIXTURE,
      cipContent: cipUpdated,
      versionBdpm: '2026-06-01',
    });
    const [doli] = await env.handle.db
      .select()
      .from(medicamentsBdpm)
      .where(eq(medicamentsBdpm.cis, '60002283'));
    expect(doli?.tauxRemboursement).toBe(30);
    expect(doli?.versionBdpm).toBe('2026-06-01');
  });

  it('perf : 5000 CIS synthétiques importés en moins de 5 s', async () => {
    const cisLines: string[] = [];
    const cipLines: string[] = [];
    for (let i = 0; i < 5000; i++) {
      const cis = String(60000000 + i);
      const cip13 = String(3400900000000 + i);
      cisLines.push(
        `${cis}\tMEDOC ${String(i)}, comprimé\tcomprimé\torale\tAutorisation active\tProcédure nationale\tCommercialisée\t01/01/2020\t\t\tEDITEUR\tNon`,
      );
      cipLines.push(
        `${cis}\t${cip13}\tboîte\tPrésentation active\tDéclaration\t01/01/2020\t${cip13}\toui\t65%\t1,00\t1,00\t`,
      );
    }
    const result = await importBdpm(env.handle.db, {
      cisContent: cisLines.join('\n'),
      cipContent: cipLines.join('\n'),
      versionBdpm: '2026-05-01',
    });
    expect(result.rowsInserted).toBe(5000);
    expect(result.durationMs).toBeLessThan(5000);
  });
});
