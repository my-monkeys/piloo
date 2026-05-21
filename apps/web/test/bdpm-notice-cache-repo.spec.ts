// Tests du repo bdpm_notices_cache : couvre les invariants critiques
// (fraîcheur, verrou refresh atomique, upsert idempotent).
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { sql } from 'drizzle-orm';

import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';

import {
  STALE_AFTER_MS,
  clearRefreshLock,
  getNoticeCache,
  isStale,
  tryAcquireRefreshLock,
  upsertNoticeCache,
} from '@/lib/bdpm/notice-cache-repo';

const CIS = '60234100';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.db.execute(sql`DELETE FROM bdpm_notices_cache`);
});

describe('bdpm_notices_cache repo', () => {
  it('upsertNoticeCache insert puis renvoie la même row au get', async () => {
    await upsertNoticeCache(env.handle.db, {
      cis: CIS,
      sourceUrl: 'http://example.com/notice',
      sections: [{ number: '4.1', title: 'Indications', text: 'Douleur.' }],
    });
    const row = await getNoticeCache(env.handle.db, CIS);
    expect(row?.cis).toBe(CIS);
    expect(row?.sections).toHaveLength(1);
    expect(row?.refreshing).toBe(false);
  });

  it('upsertNoticeCache écrase la row existante et met à jour scrapedAt', async () => {
    await upsertNoticeCache(env.handle.db, {
      cis: CIS,
      sourceUrl: 'http://example.com/v1',
      sections: [{ number: '4.1', title: 'v1', text: 'old' }],
    });
    const first = await getNoticeCache(env.handle.db, CIS);
    await new Promise((r) => setTimeout(r, 50));
    await upsertNoticeCache(env.handle.db, {
      cis: CIS,
      sourceUrl: 'http://example.com/v2',
      sections: [{ number: '4.1', title: 'v2', text: 'new' }],
    });
    const second = await getNoticeCache(env.handle.db, CIS);
    expect(second?.sourceUrl).toBe('http://example.com/v2');
    expect(second!.scrapedAt.getTime()).toBeGreaterThan(first!.scrapedAt.getTime());
  });

  it('isStale est false pour une entrée fraîche, true au-delà de 7 jours', async () => {
    await upsertNoticeCache(env.handle.db, {
      cis: CIS,
      sourceUrl: 'http://example.com',
      sections: [],
    });
    const fresh = await getNoticeCache(env.handle.db, CIS);
    expect(isStale(fresh!)).toBe(false);

    await env.handle.db.execute(sql`
      UPDATE bdpm_notices_cache
      SET scraped_at = now() - interval '8 days'
      WHERE cis = ${CIS}
    `);
    const stale = await getNoticeCache(env.handle.db, CIS);
    expect(isStale(stale!)).toBe(true);
  });

  it('tryAcquireRefreshLock refuse si la row est encore fraîche', async () => {
    await upsertNoticeCache(env.handle.db, {
      cis: CIS,
      sourceUrl: 'http://example.com',
      sections: [],
    });
    const got = await tryAcquireRefreshLock(env.handle.db, CIS);
    expect(got).toBe(false);
  });

  it('tryAcquireRefreshLock accorde 1 lock pour une row stale, refuse les suivants', async () => {
    await upsertNoticeCache(env.handle.db, {
      cis: CIS,
      sourceUrl: 'http://example.com',
      sections: [],
    });
    await env.handle.db.execute(sql`
      UPDATE bdpm_notices_cache
      SET scraped_at = now() - interval '8 days'
      WHERE cis = ${CIS}
    `);
    const first = await tryAcquireRefreshLock(env.handle.db, CIS);
    const second = await tryAcquireRefreshLock(env.handle.db, CIS);
    expect(first).toBe(true);
    expect(second).toBe(false);
  });

  it('clearRefreshLock remet refreshing=false', async () => {
    await upsertNoticeCache(env.handle.db, {
      cis: CIS,
      sourceUrl: 'http://example.com',
      sections: [],
    });
    await env.handle.db.execute(sql`
      UPDATE bdpm_notices_cache
      SET scraped_at = now() - interval '8 days', refreshing = true
      WHERE cis = ${CIS}
    `);
    await clearRefreshLock(env.handle.db, CIS);
    const after = await getNoticeCache(env.handle.db, CIS);
    expect(after?.refreshing).toBe(false);
  });

  it('STALE_AFTER_MS = 7 jours en ms', () => {
    expect(STALE_AFTER_MS).toBe(7 * 24 * 60 * 60 * 1000);
  });
});
