#!/usr/bin/env node
// CLI de génération des résumés IA pour la BDPM (#165 / #167).
//
// Usage :
//   pnpm --filter web bdpm:summaries [--limit N] [--throttle-ms N]
//
// Resumable : skip les lignes déjà enrichies avec la version courante.
// Le compteur initial (countPendingSummaries) indique combien il reste
// à traiter avant de lancer.
//
// Cost reminder : ~$3 pour les 21k médocs avec claude-haiku-4-5.
// Le script affiche progress + stats finales.
import { parseArgs } from 'node:util';

import { getDb } from '../lib/db/index.ts';
import { countPendingSummaries, runSummaryGeneration } from '../lib/bdpm/ai-summary.ts';
import { log } from '../lib/server/logger.ts';

const { values } = parseArgs({
  options: {
    limit: { type: 'string' },
    'throttle-ms': { type: 'string' },
  },
});

const limit = values.limit ? Number.parseInt(values.limit, 10) : undefined;
const throttleMs = values['throttle-ms'] ? Number.parseInt(values['throttle-ms'], 10) : undefined;

const db = getDb();

const pending = await countPendingSummaries(db);
log.info('bdpm.summaries.start', { pending, limit: limit ?? 'all', throttleMs });
if (pending === 0) {
  log.info('bdpm.summaries.nothing_to_do', {});
  process.exit(0);
}

const result = await runSummaryGeneration(db, { limit, throttleMs });
log.info('bdpm.summaries.done', result);
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
process.exit(0);
