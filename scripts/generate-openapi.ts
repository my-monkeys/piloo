#!/usr/bin/env -S node --experimental-strip-types --no-warnings=ExperimentalWarning
import { spawnSync, type SpawnSyncOptionsWithStringEncoding } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export type StepStatus = 'ok' | 'skipped' | 'failed';

export interface Step {
  name: string;
  command: string;
  args: readonly string[];
  optional?: boolean;
  requiresFile?: string;
}

export interface StepResult {
  name: string;
  status: StepStatus;
  exitCode: number | null;
  reason?: string;
}

export interface RunnerEnv {
  cwd: string;
  exec: (cmd: string, args: readonly string[], cwd: string) => { exitCode: number | null };
  fileExists: (path: string) => boolean;
  log: (line: string) => void;
}

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export const DEFAULT_STEPS: readonly Step[] = [
  {
    name: 'api-contract:generate',
    command: 'pnpm',
    args: ['--filter', '@piloo/api-contract', 'generate'],
  },
  {
    name: 'ts-client',
    command: 'bash',
    args: ['scripts/generate-ts-client.sh'],
    optional: true,
    requiresFile: 'scripts/generate-ts-client.sh',
  },
  {
    name: 'dart-client',
    command: 'bash',
    args: ['scripts/generate-dart-client.sh'],
    optional: true,
    requiresFile: 'scripts/generate-dart-client.sh',
  },
];

export function runSteps(steps: readonly Step[], env: RunnerEnv): StepResult[] {
  const results: StepResult[] = [];

  for (const step of steps) {
    if (step.requiresFile && !env.fileExists(resolve(env.cwd, step.requiresFile))) {
      const reason = `missing ${step.requiresFile}`;
      if (step.optional) {
        env.log(`▶ ${step.name}: skipped (${reason})`);
        results.push({ name: step.name, status: 'skipped', exitCode: null, reason });
        continue;
      }
      env.log(`✗ ${step.name}: failed (${reason})`);
      results.push({ name: step.name, status: 'failed', exitCode: null, reason });
      return results;
    }

    env.log(`▶ ${step.name}: ${step.command} ${step.args.join(' ')}`);
    const { exitCode } = env.exec(step.command, step.args, env.cwd);

    if (exitCode === 0) {
      env.log(`✓ ${step.name}: ok`);
      results.push({ name: step.name, status: 'ok', exitCode });
      continue;
    }

    env.log(`✗ ${step.name}: failed (exit ${exitCode ?? 'null'})`);
    results.push({ name: step.name, status: 'failed', exitCode });
    return results;
  }

  return results;
}

function defaultExec(cmd: string, args: readonly string[], cwd: string): { exitCode: number | null } {
  const opts: SpawnSyncOptionsWithStringEncoding = {
    cwd,
    stdio: 'inherit',
    encoding: 'utf8',
  };
  const result = spawnSync(cmd, args, opts);
  if (result.error) {
    process.stderr.write(`error spawning ${cmd}: ${result.error.message}\n`);
    return { exitCode: 1 };
  }
  return { exitCode: result.status };
}

function main(): number {
  const env: RunnerEnv = {
    cwd: REPO_ROOT,
    exec: defaultExec,
    fileExists: existsSync,
    log: (line) => process.stdout.write(`${line}\n`),
  };

  const results = runSteps(DEFAULT_STEPS, env);
  const failed = results.find((r) => r.status === 'failed');
  if (failed) {
    env.log('');
    env.log(`generate-openapi: failed at step "${failed.name}"`);
    return failed.exitCode ?? 1;
  }
  env.log('');
  env.log('generate-openapi: done');
  return 0;
}

const isDirectRun = (() => {
  if (typeof process.argv[1] !== 'string') return false;
  try {
    return resolve(process.argv[1]) === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
})();

if (isDirectRun) {
  process.exit(main());
}
