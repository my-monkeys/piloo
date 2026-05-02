import { describe, expect, it, vi } from 'vitest';
import { runSteps, type RunnerEnv, type Step } from './generate-openapi.ts';

function makeEnv(overrides: Partial<RunnerEnv> = {}): RunnerEnv {
  return {
    cwd: '/repo',
    exec: vi.fn(() => ({ exitCode: 0 })),
    fileExists: vi.fn(() => true),
    log: vi.fn(),
    ...overrides,
  };
}

describe('runSteps', () => {
  it('runs all steps in order when each succeeds', () => {
    const exec = vi.fn(() => ({ exitCode: 0 }));
    const env = makeEnv({ exec });
    const steps: Step[] = [
      { name: 'a', command: 'pnpm', args: ['a'] },
      { name: 'b', command: 'bash', args: ['b.sh'] },
    ];

    const results = runSteps(steps, env);

    expect(results.map((r) => r.status)).toEqual(['ok', 'ok']);
    expect(exec).toHaveBeenCalledTimes(2);
    expect(exec).toHaveBeenNthCalledWith(1, 'pnpm', ['a'], '/repo');
    expect(exec).toHaveBeenNthCalledWith(2, 'bash', ['b.sh'], '/repo');
  });

  it('stops at the first failed step', () => {
    const exec = vi
      .fn()
      .mockImplementationOnce(() => ({ exitCode: 0 }))
      .mockImplementationOnce(() => ({ exitCode: 2 }));
    const env = makeEnv({ exec });
    const steps: Step[] = [
      { name: 'a', command: 'pnpm', args: ['a'] },
      { name: 'b', command: 'pnpm', args: ['b'] },
      { name: 'c', command: 'pnpm', args: ['c'] },
    ];

    const results = runSteps(steps, env);

    expect(results).toHaveLength(2);
    expect(results[1]).toMatchObject({ name: 'b', status: 'failed', exitCode: 2 });
    expect(exec).toHaveBeenCalledTimes(2);
  });

  it('skips an optional step whose required file is missing', () => {
    const exec = vi.fn(() => ({ exitCode: 0 }));
    const fileExists = vi.fn((path: string) => !path.endsWith('missing.sh'));
    const env = makeEnv({ exec, fileExists });
    const steps: Step[] = [
      { name: 'a', command: 'pnpm', args: ['a'] },
      {
        name: 'optional-missing',
        command: 'bash',
        args: ['scripts/missing.sh'],
        optional: true,
        requiresFile: 'scripts/missing.sh',
      },
      { name: 'c', command: 'pnpm', args: ['c'] },
    ];

    const results = runSteps(steps, env);

    expect(results.map((r) => r.status)).toEqual(['ok', 'skipped', 'ok']);
    expect(exec).toHaveBeenCalledTimes(2);
    expect(exec).not.toHaveBeenCalledWith('bash', ['scripts/missing.sh'], expect.anything());
  });

  it('fails a non-optional step whose required file is missing without spawning it', () => {
    const exec = vi.fn(() => ({ exitCode: 0 }));
    const fileExists = vi.fn(() => false);
    const env = makeEnv({ exec, fileExists });
    const steps: Step[] = [
      {
        name: 'required-missing',
        command: 'bash',
        args: ['scripts/required.sh'],
        requiresFile: 'scripts/required.sh',
      },
      { name: 'never', command: 'pnpm', args: ['never'] },
    ];

    const results = runSteps(steps, env);

    expect(results).toHaveLength(1);
    expect(results[0]).toMatchObject({ name: 'required-missing', status: 'failed' });
    expect(exec).not.toHaveBeenCalled();
  });
});
