// Test du calcul de coût LLM (#165).
//
// Vérifie computeCostUsd + cohérence avec les prix Gemini 2.5 Flash
// publics. Si le test casse, c'est probablement que Google a révisé
// les tarifs — mettre à jour SUMMARY_PRICING_USD en conséquence.
import { describe, expect, it } from 'vitest';

import { computeCostUsd, SUMMARY_PRICING_USD } from '@/lib/bdpm/ai-summary';

describe('computeCostUsd', () => {
  it('retourne 0 pour 0 tokens', () => {
    expect(computeCostUsd(0, 0)).toBe(0);
  });

  it('1M input tokens = inputPerMillion USD', () => {
    expect(computeCostUsd(1_000_000, 0)).toBeCloseTo(SUMMARY_PRICING_USD.inputPerMillion, 6);
  });

  it('1M output tokens = outputPerMillion USD', () => {
    expect(computeCostUsd(0, 1_000_000)).toBeCloseTo(SUMMARY_PRICING_USD.outputPerMillion, 6);
  });

  it('cas réaliste : 150 input + 80 output × 21k médocs (BDPM)', () => {
    const total = computeCostUsd(150 * 21_000, 80 * 21_000);
    // 3.15M input × 0.30 = 0.945 + 1.68M output × 2.50 = 4.20 → ~5.15 USD
    expect(total).toBeGreaterThan(4);
    expect(total).toBeLessThan(7);
  });

  it('pricing constants positifs', () => {
    expect(SUMMARY_PRICING_USD.inputPerMillion).toBeGreaterThan(0);
    expect(SUMMARY_PRICING_USD.outputPerMillion).toBeGreaterThan(0);
    expect(SUMMARY_PRICING_USD.outputPerMillion).toBeGreaterThan(
      SUMMARY_PRICING_USD.inputPerMillion,
    );
  });
});
