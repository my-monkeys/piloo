import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const SCRIPT = join(__dirname, 'generate-ts-client.sh');

describe('generate-ts-client.sh', () => {
  it('is executable', () => {
    const mode = statSync(SCRIPT).mode;
    expect(mode & 0o111).not.toBe(0);
  });

  it('fails with a clear message when the OpenAPI spec is missing', () => {
    const work = mkdtempSync(join(tmpdir(), 'piloo-gen-ts-'));
    const result = spawnSync('bash', [SCRIPT], {
      env: {
        ...process.env,
        OPENAPI_SPEC: join(work, 'does-not-exist.yaml'),
        OUTPUT_PATH: join(work, 'out.ts'),
      },
      encoding: 'utf8',
    });
    expect(result.status).not.toBe(0);
    expect(result.stderr).toMatch(/OpenAPI spec not found/);
  });

  it('runs openapi-typescript against a minimal spec when the runner is available', () => {
    const hasNpx = spawnSync('npx', ['--version']).status === 0;
    if (!hasNpx) return;

    const work = mkdtempSync(join(tmpdir(), 'piloo-gen-ts-'));
    const spec = join(work, 'openapi.yaml');
    const out = join(work, 'types.ts');

    writeFileSync(
      spec,
      [
        'openapi: 3.1.0',
        'info:',
        '  title: piloo-test',
        '  version: 0.0.0',
        'paths:',
        '  /ping:',
        '    get:',
        '      responses:',
        "        '200':",
        '          description: ok',
        '',
      ].join('\n'),
    );

    try {
      execFileSync('bash', [SCRIPT], {
        env: { ...process.env, OPENAPI_SPEC: spec, OUTPUT_PATH: out },
        stdio: 'pipe',
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      // Skip silently if the test environment can't reach the npm registry.
      if (/ENOTFOUND|ETIMEDOUT|registry|network/i.test(msg)) return;
      throw err;
    }

    const generated = readFileSync(out, 'utf8');
    expect(generated).toMatch(/\/ping/);
    expect(generated).toMatch(/paths/);
  }, 120_000);
});
