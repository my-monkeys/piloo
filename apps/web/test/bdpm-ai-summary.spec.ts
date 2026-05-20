// Sanity test du module ai-summary (#167).
//
// On ne couvre PAS l'intégration Anthropic (coût + non-déterminisme) —
// juste la signature publique pour s'assurer que l'API key est bien
// requise et que les exports sont stables.
import { describe, expect, it } from 'vitest';

import { runSummaryGeneration } from '@/lib/bdpm/ai-summary';

describe('runSummaryGeneration', () => {
  it('throw si GEMINI_API_KEY absente', async () => {
    const originalGemini = process.env['GEMINI_API_KEY'];
    const originalGoogle = process.env['GOOGLE_API_KEY'];
    delete process.env['GEMINI_API_KEY'];
    delete process.env['GOOGLE_API_KEY'];
    try {
      await expect(
        // db dummy — la fonction throw avant d'y toucher.
        runSummaryGeneration({} as never, { apiKey: undefined }),
      ).rejects.toThrow('GEMINI_API_KEY');
    } finally {
      if (originalGemini !== undefined) {
        process.env['GEMINI_API_KEY'] = originalGemini;
      }
      if (originalGoogle !== undefined) {
        process.env['GOOGLE_API_KEY'] = originalGoogle;
      }
    }
  });
});
