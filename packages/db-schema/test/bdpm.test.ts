import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { medicamentsBdpm, type NewMedicamentBdpm } from '../src/schema/index.ts';
import { setupTestDb, truncateAll, type TestDb } from './setup.ts';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 60_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await truncateAll(env.handle);
});

const baseRow = (overrides: Partial<NewMedicamentBdpm> = {}): NewMedicamentBdpm => ({
  cis: '60000001',
  cip13: '3400930000001',
  cip7: '3000001',
  denomination: 'DOLIPRANE 1000mg cp',
  forme: 'comprimé',
  dosage: '1000mg',
  voieAdministration: 'orale',
  titulaire: 'SANOFI',
  statutAmm: 'Autorisation active',
  tauxRemboursement: 65,
  versionBdpm: '2026-04-01',
  ...overrides,
});

describe('medicaments_bdpm', () => {
  it('insère une ligne BDPM minimale (cip13 + cis + denomination + version requis)', async () => {
    const [row] = await env.handle.db
      .insert(medicamentsBdpm)
      .values({
        cip13: '3400930000077',
        cis: '99999999',
        denomination: 'PARACETAMOL 500mg',
        versionBdpm: '2026-01-01',
      })
      .returning();
    expect(row?.cip13).toBe('3400930000077');
    expect(row?.cis).toBe('99999999');
    expect(row?.denomination).toBe('PARACETAMOL 500mg');
    expect(row?.tauxRemboursement).toBeNull();
  });

  it('rejette un CIP13 dupliqué (PK)', async () => {
    await env.handle.db.insert(medicamentsBdpm).values(baseRow());
    await expect(env.handle.db.insert(medicamentsBdpm).values(baseRow())).rejects.toMatchObject({
      cause: { message: expect.stringMatching(/duplicate key|medicaments_bdpm_pkey/) },
    });
  });

  it('autorise plusieurs CIP13 distincts partageant le même CIS (présentations multiples)', async () => {
    await env.handle.db
      .insert(medicamentsBdpm)
      .values(baseRow({ cis: '60000099', cip13: '3400930000088' }));
    const [row2] = await env.handle.db
      .insert(medicamentsBdpm)
      .values(baseRow({ cis: '60000099', cip13: '3400930000095' }))
      .returning();
    expect(row2?.cip13).toBe('3400930000095');
    expect(row2?.cis).toBe('60000099');
  });
});
