import worker from '../src/index';
import { describe, expect, it } from 'vitest';

describe('D02 Worker edge contract', () => {
  it('reports health with a request ID and no sensitive environment details', async () => {
    const response = await worker.fetch(new Request('https://api.test/health'));
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body).toMatchObject({ data: { status: 'ok' } });
    expect(response.headers.get('X-Request-Id')).toBeTruthy();
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(Object.keys(body as object).sort()).toEqual(['data', 'requestId']);
  });

  it('returns a stable error for an unknown path', async () => {
    const response = await worker.fetch(new Request('https://api.test/unknown'));
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({
      error: { code: 'NOT_FOUND', messageKey: 'api.notFound', retryable: false },
    });
  });

  it('rejects malformed JSON before auth exchange', async () => {
    const response = await worker.fetch(new Request('https://api.test/v1/auth/google', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{',
    }));
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: { code: 'INVALID_JSON' } });
  });
});
