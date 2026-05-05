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
  it('insère une ligne BDPM minimale (denomination + cis + version requis)', async () => {
    const [row] = await env.handle.db
      .insert(medicamentsBdpm)
      .values({
        cis: '99999999',
        denomination: 'PARACETAMOL 500mg',
        versionBdpm: '2026-01-01',
      })
      .returning();
    expect(row?.cis).toBe('99999999');
    expect(row?.denomination).toBe('PARACETAMOL 500mg');
    expect(row?.tauxRemboursement).toBeNull();
  });

  it('rejette un CIS dupliqué (PK)', async () => {
    await env.handle.db.insert(medicamentsBdpm).values(baseRow());
    await expect(env.handle.db.insert(medicamentsBdpm).values(baseRow())).rejects.toThrow(
      /duplicate key|medicaments_bdpm_pkey/,
    );
  });

  it('autorise plusieurs lignes avec même cip13 (cas génériques + branding)', async () => {
    await env.handle.db
      .insert(medicamentsBdpm)
      .values(baseRow({ cis: '11111111', cip13: '3400930000099' }));
    const [row2] = await env.handle.db
      .insert(medicamentsBdpm)
      .values(baseRow({ cis: '22222222', cip13: '3400930000099' }))
      .returning();
    expect(row2?.cis).toBe('22222222');
  });
});
