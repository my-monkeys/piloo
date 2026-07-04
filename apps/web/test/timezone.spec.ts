import { describe, it, expect } from 'vitest';

import { zonedWallClockToUtc, utcToZonedParts } from '@/lib/prises/timezone';

describe('zonedWallClockToUtc', () => {
  it('Europe/Paris en été (DST +2) : 22:00 mural → 20:00Z', () => {
    const utc = zonedWallClockToUtc(2026, 7, 3, 22, 0, 'Europe/Paris');
    expect(utc.toISOString()).toBe('2026-07-03T20:00:00.000Z');
  });

  it('Europe/Paris en hiver (+1) : 22:00 mural → 21:00Z', () => {
    const utc = zonedWallClockToUtc(2026, 1, 15, 22, 0, 'Europe/Paris');
    expect(utc.toISOString()).toBe('2026-01-15T21:00:00.000Z');
  });

  it('America/New_York en été (-4) : 08:00 mural → 12:00Z', () => {
    const utc = zonedWallClockToUtc(2026, 7, 3, 8, 0, 'America/New_York');
    expect(utc.toISOString()).toBe('2026-07-03T12:00:00.000Z');
  });

  it('UTC : identité', () => {
    const utc = zonedWallClockToUtc(2026, 7, 3, 22, 0, 'UTC');
    expect(utc.toISOString()).toBe('2026-07-03T22:00:00.000Z');
  });
});

describe('utcToZonedParts', () => {
  it('20:00Z en Europe/Paris été → 22:00 mural', () => {
    const parts = utcToZonedParts(new Date('2026-07-03T20:00:00.000Z'), 'Europe/Paris');
    expect(parts).toMatchObject({ year: 2026, month: 7, day: 3, hour: 22, minute: 0 });
  });

  it('23:30Z en Europe/Paris été → 01:30 le lendemain', () => {
    const parts = utcToZonedParts(new Date('2026-07-03T23:30:00.000Z'), 'Europe/Paris');
    expect(parts).toMatchObject({ year: 2026, month: 7, day: 4, hour: 1, minute: 30 });
  });
});
