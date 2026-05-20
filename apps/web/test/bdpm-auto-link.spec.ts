// Tests unitaires extractRestNotes (logique pure du auto-link BDPM #55).
//
// L'intégration DB est couverte par bdpm-api.spec.ts (qui utilise
// testcontainers). Ici on couvre juste la séparation notes pour ne pas
// dépendre de Postgres.
import { describe, expect, it } from 'vitest';

import { __testing } from '@/lib/bdpm/auto-link';

const { extractRestNotes } = __testing;

describe('extractRestNotes', () => {
  it('retourne null si pas de séparateur', () => {
    expect(extractRestNotes('CIP 3400921905076')).toBeNull();
  });

  it('retourne null si notes nulles', () => {
    expect(extractRestNotes(null)).toBeNull();
  });

  it('extrait la partie après " // "', () => {
    expect(extractRestNotes('CIP 3400921905076 // dans le tiroir cuisine')).toBe(
      'dans le tiroir cuisine',
    );
  });

  it('préserve les séparateurs internes', () => {
    expect(extractRestNotes('CIP 3400921905076 // note 1 // note 2')).toBe('note 1 // note 2');
  });
});
