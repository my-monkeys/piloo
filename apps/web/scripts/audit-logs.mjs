#!/usr/bin/env node
// Audit CI : aucune log brute de donnée patient (#97).
//
// Règle : tout logging dans `apps/web/` doit passer par
// `lib/server/logger.ts` qui sanitize. Cette grep échoue si on
// trouve un `console.log/info/warn/error` dans le code de l'app
// (en dehors de tests, scripts utilitaires, et du logger lui-même).
//
// Pour les cas où on a vraiment besoin de console.log (debug local),
// on tolère un commentaire `// audit-logs: allow` sur la même ligne.
import { readFileSync, statSync, readdirSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = process.cwd();
const SCAN_DIRS = ['app', 'lib', 'components'];
const ALLOWED_FILES = new Set([
  'lib/server/logger.ts', // c'est lui qui appelle console.* à la fin du pipeline
]);
const FORBIDDEN = /\bconsole\.(log|info|warn|error|debug|trace)\s*\(/;
const ALLOW_LINE = /audit-logs:\s*allow/;

let violations = 0;

function walk(dir) {
  const entries = readdirSync(dir);
  for (const entry of entries) {
    if (entry === 'node_modules' || entry === '.next' || entry.startsWith('.')) {
      continue;
    }
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      walk(full);
    } else if (/\.(ts|tsx|mjs|js)$/.test(entry)) {
      auditFile(full);
    }
  }
}

function auditFile(path) {
  const rel = relative(ROOT, path);
  if (ALLOWED_FILES.has(rel)) return;
  const content = readFileSync(path, 'utf8');
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!FORBIDDEN.test(line)) continue;
    if (ALLOW_LINE.test(line)) continue;
    console.error(`${rel}:${i + 1}  console.* call — utiliser lib/server/logger`);
    violations++;
  }
}

for (const d of SCAN_DIRS) {
  const full = join(ROOT, d);
  try {
    if (statSync(full).isDirectory()) walk(full);
  } catch {
    // dossier absent : on ignore.
  }
}

if (violations > 0) {
  console.error(`\n[audit-logs] ${violations} violation(s) trouvée(s).`);
  process.exit(1);
}
console.log('[audit-logs] OK');
