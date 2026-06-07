// Régression #353 : le client web tapait `/v1/*` au lieu de `/api/v1/*`
// (les routes Next.js vivent sous `/api/...`), d'où des 404 sur toutes les
// requêtes une fois en prod. On verrouille le base path ici.
import { describe, expect, it, vi } from 'vitest';

import { API_BASE_PATH, createPilooApiClient } from './index.ts';

function recordingFetch(urls: string[]): typeof fetch {
  return vi.fn((input: unknown) => {
    const url =
      typeof input === 'string'
        ? input
        : input instanceof URL
          ? input.toString()
          : (input as { url: string }).url;
    urls.push(url);
    return Promise.resolve(
      new Response('{"items":[]}', {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );
  });
}

describe('@piloo/api-client', () => {
  it('expose le préfixe /api attendu par les routes Next (#353)', () => {
    expect(API_BASE_PATH).toBe('/api');
  });

  it('joint le baseUrl au chemin OpenAPI /v1/* → /api/v1/*', async () => {
    const urls: string[] = [];
    const { apiClient } = createPilooApiClient({
      // baseUrl absolu : `openapi-fetch` fait `new URL(...)`, qui exige une
      // URL absolue hors navigateur. On reproduit `${origin}${API_BASE_PATH}`.
      baseUrl: `https://piloo.test${API_BASE_PATH}`,
      fetch: recordingFetch(urls),
    });

    await apiClient.GET('/v1/officines');

    expect(urls).toEqual(['https://piloo.test/api/v1/officines']);
  });
});
