#!/usr/bin/env -S node --experimental-strip-types --no-warnings=ExperimentalWarning
// Construit le document OpenAPI depuis les schémas Zod et écrit
// `packages/api-contract/openapi.yaml`. Lancé par `pnpm --filter
// @piloo/api-contract generate` (cf. turbo.json task `openapi:generate`).
import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { stringify } from 'yaml';

// Important : importer le barrel des schémas pour que chaque module appelle
// `registry.registerPath(...)` avant la construction du document.
import '../src/schemas/index.ts';
import { buildOpenApiDocument } from '../src/openapi.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
const PACKAGE_ROOT = resolve(HERE, '..');
const OUTPUT_PATH = resolve(PACKAGE_ROOT, 'openapi.yaml');

const document = buildOpenApiDocument();
const yaml = stringify(document, { lineWidth: 0 });

writeFileSync(OUTPUT_PATH, yaml, 'utf8');

const pathsCount = Object.keys(document.paths ?? {}).length;
const componentsCount = Object.keys(document.components?.schemas ?? {}).length;
console.info(
  `✓ openapi.yaml — ${String(pathsCount)} path(s), ${String(componentsCount)} schema(s)`,
);
