// Test pur du mapping quantité rappel → prise selon le fuseau officine (#363).
import type { PrisePlanifiee, Rappel } from '@piloo/db-schema';
import { describe, expect, it } from 'vitest';

import { serializePriseTimelineItem } from '@/lib/prises/serialize';

const prise = {
  id: '00000000-0000-0000-0000-0000000000p1',
  officineId: '00000000-0000-0000-0000-0000000000o1',
  datetimePrevue: new Date('2026-07-03T20:00:00.000Z'),
  datetimeValidation: null,
  statut: 'prevue',
  notes: null,
} as unknown as PrisePlanifiee;

const rappelBase = {
  id: '00000000-0000-0000-0000-0000000000r1',
  nomTexte: 'Doliprane',
  cip13: null,
  unite: 'comprimé',
  quantiteMatin: null,
  quantiteMidi: null,
  quantiteSoir: null,
  quantiteCoucher: null,
} as unknown as Rappel;

describe('serializePriseTimelineItem — fuseau officine', () => {
  it('20:00Z en Europe/Paris (22:00 mural) → créneau coucher → quantité coucher', () => {
    const rappel = { ...rappelBase, quantiteCoucher: 2 } as Rappel;
    const item = serializePriseTimelineItem(prise, null, rappel, 'Europe/Paris');
    expect(item.prescription.posologie['unitesParPrise']).toBe(2);
  });

  it('même instant lu en UTC (20:00) → créneau soir → quantité soir', () => {
    const rappel = { ...rappelBase, quantiteSoir: 5 } as Rappel;
    const item = serializePriseTimelineItem(prise, null, rappel, 'UTC');
    expect(item.prescription.posologie['unitesParPrise']).toBe(5);
  });
});
