import worker from '../src/index';
import { describe, expect, it } from 'vitest';
import { createApp } from '../src/http/router';
import { MAX_JSON_BODY_BYTES } from '../src/http/schemas';
import type { RequestEvent } from '../src/telemetry/request-event';
import { syntheticAuthenticator } from './helpers/auth';

describe('D02 Worker edge contract', () => {
  it('reports health with a request ID and no sensitive environment details', async () => {
    const response = await worker.fetch(new Request('https://api.test/health'));
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body).toMatchObject({ data: { status: 'ok', apiVersion:1, capabilities:expect.arrayContaining(['owner-ledger-sync-v1','immutable-corrections-v1','disputes-v1','due-allocation-v1','privacy-requests-v1']) } });
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

  it('rejects an unsupported method and advertises the allowed one', async () => {
    const response = await worker.fetch(new Request('https://api.test/health', { method: 'POST' }));
    expect(response.status).toBe(405);
    expect(response.headers.get('Allow')).toBe('GET');
  });

  it.each([
    ['text/plain', '{}'],
    [null, '{}'],
  ])('requires JSON media type (%s)', async (contentType, body) => {
    const headers: Record<string, string> = contentType ? { 'Content-Type': contentType } : {};
    const response = await worker.fetch(new Request('https://api.test/v1/auth/google', { method: 'POST', headers, body }));
    expect(response.status).toBe(415);
  });

  it('does not accept encoded bodies', async () => {
    const response = await worker.fetch(new Request('https://api.test/v1/auth/google', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Encoding': 'gzip' }, body: '{}',
    }));
    expect(response.status).toBe(415);
  });

  it.each(['{}', 'null', '{"idToken":"x","requestedRole":"admin"}',
    '{"idToken":"x","requestedRole":"owner","shopId":"other"}',
    '{"idToken":"","requestedRole":"owner"}'])('rejects invalid or unknown auth fields: %s', async (body) => {
    const response = await worker.fetch(new Request('https://api.test/v1/auth/google', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body,
    }));
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: { code: 'VALIDATION_ERROR' } });
  });

  it('reports the unavailable auth feature without issuing a fake token', async () => {
    const response = await worker.fetch(new Request('https://api.test/v1/auth/google', {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify({ idToken: 'synthetic', requestedRole: 'owner' }),
    }));
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({ error: { code: 'FEATURE_UNAVAILABLE', retryable: true } });
  });

  it('rejects declared oversized bodies', async () => {
    const response = await worker.fetch(new Request('https://api.test/v1/auth/google', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': `${MAX_JSON_BODY_BYTES + 1}` },
      body: '{}',
    }));
    expect(response.status).toBe(413);
    expect(await response.json()).toMatchObject({ error: { code: 'PAYLOAD_TOO_LARGE' } });
  });

  it('counts actual streamed bytes when Content-Length is absent', async () => {
    const body = new ReadableStream<Uint8Array>({ start(controller) {
      controller.enqueue(new TextEncoder().encode('प'.repeat(MAX_JSON_BODY_BYTES / 2)));
      controller.close();
    } });
    const response = await worker.fetch(new Request('https://api.test/v1/auth/google', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body,
    }));
    expect(response.status).toBe(413);
  });

  it('rejects empty and malformed UTF-8 bodies', async () => {
    for (const body of [null, new Uint8Array([0xff])]) {
      const response = await worker.fetch(new Request('https://api.test/v1/auth/google', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body,
      }));
      expect(response.status).toBe(400);
    }
  });

  it('uses its own request ID and rejects unverified bearer claims', async () => {
    const response = await worker.fetch(new Request('https://api.test/v1/me', {
      headers: { Authorization: 'Bearer forged-owner', 'X-Request-Id': 'untrusted' },
    }));
    expect(response.status).toBe(401);
    const body = await response.json() as { requestId: string };
    expect(body.requestId).toBe(response.headers.get('X-Request-Id'));
    expect(body.requestId).not.toBe('untrusted');
  });

  it('uses synthetic verified identities only through injected test helpers', async () => {
    const app = createApp({ authenticate: syntheticAuthenticator('owner'), logger: () => {} });
    const response = await app.fetch(new Request('https://api.test/v1/me'));
    expect(response.status).toBe(503);
  });

  it('redacts unexpected errors, raw paths, query values, and credentials from telemetry', async () => {
    const events: RequestEvent[] = [];
    const secret = 'SENSITIVE_SENTINEL';
    const app = createApp({ authenticate: async () => { throw new Error(secret); }, logger: (event) => events.push(event) });
    const response = await app.fetch(new Request(`https://api.test/v1/me?token=${secret}`, {
      headers: { Authorization: `Bearer ${secret}` },
    }));
    expect(response.status).toBe(500);
    const errorBody = await response.json();
    expect(errorBody).toMatchObject({ error: { code: 'SERVER_ERROR' } });
    expect(JSON.stringify(errorBody)).not.toContain(secret);
    await app.fetch(new Request(`https://api.test/${secret}?qr=${secret}`));
    expect(JSON.stringify(events)).not.toContain(secret);
    expect(events.map((event) => event.route)).toEqual(['/v1/me', 'unmatched']);
    expect(Object.keys(events[0]).sort()).toEqual(['durationMs', 'errorCode', 'requestId', 'route', 'status']);
  });

  it('keeps the API outcome even if telemetry fails', async () => {
    const app = createApp({ logger: () => { throw new Error('log failure'); } });
    expect((await app.fetch(new Request('https://api.test/health'))).status).toBe(200);
  });
});
