import type { Authenticator } from '../auth/authenticator';
import { unavailableAuthenticator } from '../auth/authenticator';
import { requirePrincipal } from '../policy/access';
import { logRequest, type RequestLogger } from '../telemetry/request-event';
import { errorResponse, HttpError, jsonResponse } from './errors';
import { googleExchangeSchema, readJson } from './schemas';

interface Route {
  path: string;
  method: string;
  handler: (request: Request, requestId: string) => Promise<Response>;
}

export function createApp(options: { authenticate?: Authenticator; logger?: RequestLogger } = {}) {
  const authenticate = options.authenticate ?? unavailableAuthenticator;
  const logger = options.logger ?? logRequest;
  const unavailable = () => { throw new HttpError(503, 'FEATURE_UNAVAILABLE', 'api.featureUnavailable', true); };
  const routes: Route[] = [
    { path: '/health', method: 'GET', handler: async (_, requestId) => jsonResponse({ status: 'ok' }, requestId) },
    { path: '/v1/auth/google', method: 'POST', handler: async (request) => {
      await readJson(request, googleExchangeSchema);
      return unavailable();
    } },
    { path: '/v1/me', method: 'GET', handler: async (request) => {
      requirePrincipal(await authenticate(request));
      return unavailable();
    } },
  ];

  return {
    async fetch(request: Request): Promise<Response> {
      const requestId = crypto.randomUUID();
      const started = performance.now();
      let routeTemplate = 'unmatched';
      let response: Response;
      let errorCode: string | null = null;
      try {
        const path = new URL(request.url).pathname;
        const matching = routes.filter((route) => route.path === path);
        if (matching.length === 0) throw new HttpError(404, 'NOT_FOUND', 'api.notFound');
        routeTemplate = matching[0].path;
        const route = matching.find((candidate) => candidate.method === request.method);
        if (!route) throw new HttpError(405, 'METHOD_NOT_ALLOWED', 'api.methodNotAllowed', false, {
          Allow: matching.map((candidate) => candidate.method).join(', '),
        });
        response = await route.handler(request, requestId);
      } catch (error) {
        const safe = error instanceof HttpError ? error : new HttpError(500, 'SERVER_ERROR', 'api.internalError', true);
        errorCode = safe.code;
        response = errorResponse(safe, requestId);
      }
      try {
        logger({ requestId, route: routeTemplate, status: response.status, errorCode,
          durationMs: Math.max(0, Math.round(performance.now() - started)) });
      } catch { /* A telemetry failure must not change the API outcome. */ }
      return response;
    },
  };
}
