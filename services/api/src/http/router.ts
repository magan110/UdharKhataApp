import type { Authenticator } from '../auth/authenticator';
import { unavailableAuthenticator } from '../auth/authenticator';
import { requirePrincipal } from '../policy/access';
import { logRequest, type RequestLogger } from '../telemetry/request-event';
import { errorResponse, HttpError, jsonResponse } from './errors';
import { googleExchangeSchema, refreshSchema, logoutSchema, readJson } from './schemas';
import type { GoogleIdentity } from '../auth/google';
import type { SessionService } from '../auth/sessions';
import { z } from 'zod';

interface Route {
  path: string;
  method: string;
  handler: (request: Request, requestId: string) => Promise<Response>;
}

export function createApp(options: { authenticate?: Authenticator; logger?: RequestLogger; sessions?:SessionService; verifyGoogle?:(token:string)=>Promise<GoogleIdentity> } = {}) {
  const authenticate = options.authenticate ?? unavailableAuthenticator;
  const logger = options.logger ?? logRequest;
  const unavailable = () => { throw new HttpError(503, 'FEATURE_UNAVAILABLE', 'api.featureUnavailable', true); };
  const routes: Route[] = [
    { path: '/health', method: 'GET', handler: async (_, requestId) => jsonResponse({ status: 'ok' }, requestId) },
    { path: '/v1/auth/google', method: 'POST', handler: async (request,requestId) => {
      const body=await readJson(request, googleExchangeSchema) as z.infer<typeof googleExchangeSchema>;
      if(!options.sessions || !options.verifyGoogle) return unavailable();
      await options.sessions.rateLimit(request.headers.get('CF-Connecting-IP')??'unknown','google');
      if(!body.deviceId) throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
      return jsonResponse(await options.sessions.exchange(await options.verifyGoogle(body.idToken),body.requestedRole,body.deviceId),requestId);
    } },
    { path: '/v1/auth/refresh', method: 'POST', handler: async(request,requestId)=> {
      const body=await readJson(request,refreshSchema) as z.infer<typeof refreshSchema>;
      if(!options.sessions) return unavailable();
      await options.sessions.rateLimit(request.headers.get('CF-Connecting-IP')??'unknown','refresh');
      return jsonResponse(await options.sessions.refresh(body.refreshToken,body.deviceId),requestId);
    } },
    { path: '/v1/auth/logout', method: 'POST', handler: async(request,requestId)=> {
      const body=await readJson(request,logoutSchema) as z.infer<typeof logoutSchema>;
      if(!options.sessions) return unavailable();
      await options.sessions.logout(request.headers.get('Authorization')?.match(/^Bearer ([0-9a-f]{64})$/)?.[1]??'',body.deviceId);
      return new Response(null,{status:204,headers:{'X-Request-Id':requestId,'Cache-Control':'no-store'}});
    } },
    { path: '/v1/me', method: 'GET', handler: async (request,requestId) => {
      if(options.sessions) return jsonResponse(await options.sessions.profile(request.headers.get('Authorization')?.match(/^Bearer ([0-9a-f]{64})$/)?.[1]??''),requestId);
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
