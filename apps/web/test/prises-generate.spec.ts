// Tests unitaires algorithme de génération prises_planifiees (#107).
//
// Pas de DB ici — la fonction est pure (input prescription + options
// → tableau de NewPrisePlanifiee). Les tests d'insertion DB sont
// couverts ailleurs (boites, ordonnances) sur le pattern testcontainers.
import type { Posologie, Prescription } from '@piloo/db-schema';
import { describe, expect, it } from 'vitest';

import {
  buildHorairesForDay,
  DEFAULT_HORAIRES_BY_MOMENT,
  generatePrisesForPrescription,
} from '@/lib/prises/generate';

const OFFICINE_ID = '11111111-1111-1111-1111-111111111111';
const PRESCRIPTION_ID = '22222222-2222-2222-2222-222222222222';

function makePrescription(
  posologie: Posologie,
  dureeJours: number | null,
): Pick<Prescription, 'id' | 'posologie' | 'dureeJours'> {
  return { id: PRESCRIPTION_ID, posologie, dureeJours };
}

const dateDebut = new Date('2026-06-01T00:00:00.000Z');

describe('buildHorairesForDay', () => {
  it('moments → defaults triés (matin → 08:00)', () => {
    const horaires = buildHorairesForDay({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['soir', 'matin'],
    });
    expect(horaires).toEqual(['08:00', '19:00']);
  });

  it('horaires explicites prennent le pas sur moments', () => {
    const horaires = buildHorairesForDay({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin'],
      horaires: ['07:30', '14:00'],
    });
    expect(horaires).toEqual(['07:30', '14:00']);
  });

  it('override user remplace defaults', () => {
    const horaires = buildHorairesForDay(
      {
        unitesParPrise: 1,
        unite: 'cp',
        frequence: 'quotidien',
        moments: ['matin', 'coucher'],
      },
      { matin: '07:00', coucher: '23:30' },
    );
    expect(horaires).toEqual(['07:00', '23:30']);
  });

  it('moments dupliqués résolus en un seul créneau (matin+midi avec même horaire pseudo)', () => {
    const horaires = buildHorairesForDay(
      {
        unitesParPrise: 1,
        unite: 'cp',
        frequence: 'quotidien',
        moments: ['matin', 'midi'],
      },
      { matin: '12:00', midi: '12:00' },
    );
    expect(horaires).toEqual(['12:00']);
  });

  it("rien de spécifié → 1 prise à l'horaire matin", () => {
    const horaires = buildHorairesForDay({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
    });
    expect(horaires).toEqual([DEFAULT_HORAIRES_BY_MOMENT.matin]);
  });
});

describe('generatePrisesForPrescription', () => {
  it('matin × 3 jours = 3 prises à 08:00', () => {
    const presc = makePrescription(
      { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien', moments: ['matin'] },
      3,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    expect(prises).toHaveLength(3);
    expect(prises[0]?.datetimePrevue).toEqual(new Date('2026-06-01T08:00:00.000Z'));
    expect(prises[1]?.datetimePrevue).toEqual(new Date('2026-06-02T08:00:00.000Z'));
    expect(prises[2]?.datetimePrevue).toEqual(new Date('2026-06-03T08:00:00.000Z'));
    expect(prises.every((p) => p.statut === 'prevue')).toBe(true);
    expect(prises.every((p) => p.officineId === OFFICINE_ID)).toBe(true);
    expect(prises.every((p) => p.prescriptionId === PRESCRIPTION_ID)).toBe(true);
  });

  it('matin+midi × 2 jours = 4 prises ordonnées chronologiquement', () => {
    const presc = makePrescription(
      {
        unitesParPrise: 1,
        unite: 'cp',
        frequence: 'quotidien',
        moments: ['matin', 'midi'],
      },
      2,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    expect(prises.map((p) => p.datetimePrevue.toISOString())).toEqual([
      '2026-06-01T08:00:00.000Z',
      '2026-06-01T12:00:00.000Z',
      '2026-06-02T08:00:00.000Z',
      '2026-06-02T12:00:00.000Z',
    ]);
  });

  it('horaires précis (08:30, 14:00, 22:00) × 1 jour = 3 prises', () => {
    const presc = makePrescription(
      {
        unitesParPrise: 1,
        unite: 'cp',
        frequence: 'quotidien',
        horaires: ['08:30', '14:00', '22:00'],
      },
      1,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    expect(prises.map((p) => p.datetimePrevue.toISOString())).toEqual([
      '2026-06-01T08:30:00.000Z',
      '2026-06-01T14:00:00.000Z',
      '2026-06-01T22:00:00.000Z',
    ]);
  });

  it('hebdomadaire × matin sur 21 jours = 3 prises (j0, j7, j14)', () => {
    const presc = makePrescription(
      {
        unitesParPrise: 1,
        unite: 'cp',
        frequence: 'hebdomadaire',
        moments: ['matin'],
      },
      21,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    expect(prises).toHaveLength(3);
    expect(prises.map((p) => p.datetimePrevue.toISOString())).toEqual([
      '2026-06-01T08:00:00.000Z',
      '2026-06-08T08:00:00.000Z',
      '2026-06-15T08:00:00.000Z',
    ]);
  });

  it('a_la_demande → aucune prise', () => {
    const presc = makePrescription(
      { unitesParPrise: 1, unite: 'cp', frequence: 'a_la_demande' },
      30,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    expect(prises).toEqual([]);
  });

  it('dureeJours null → aucune prise', () => {
    const presc = makePrescription(
      { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien', moments: ['matin'] },
      null,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    expect(prises).toEqual([]);
  });

  it('dureeJours = 0 → aucune prise', () => {
    const presc = makePrescription(
      { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien', moments: ['matin'] },
      0,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    expect(prises).toEqual([]);
  });

  it('override user horaires appliqués à toute la fenêtre', () => {
    const presc = makePrescription(
      { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien', moments: ['matin'] },
      2,
    );
    const prises = generatePrisesForPrescription(presc, {
      officineId: OFFICINE_ID,
      dateDebut,
      horairesUtilisateur: { matin: '07:00' },
    });
    expect(prises.map((p) => p.datetimePrevue.toISOString())).toEqual([
      '2026-06-01T07:00:00.000Z',
      '2026-06-02T07:00:00.000Z',
    ]);
  });

  it('hebdomadaire respecte dureeJours non-multiple de 7', () => {
    const presc = makePrescription(
      { unitesParPrise: 1, unite: 'cp', frequence: 'hebdomadaire', moments: ['matin'] },
      10,
    );
    const prises = generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut });
    // j0 et j7 dans la fenêtre [0, 10), j14 hors fenêtre.
    expect(prises).toHaveLength(2);
  });

  it('lance si horaire mal formé dans posologie.horaires', () => {
    const presc = makePrescription(
      {
        unitesParPrise: 1,
        unite: 'cp',
        frequence: 'quotidien',
        horaires: ['25:00'],
      },
      1,
    );
    expect(() =>
      generatePrisesForPrescription(presc, { officineId: OFFICINE_ID, dateDebut }),
    ).toThrow(/horaire invalide/);
  });
});
