import type { Authenticator } from '../auth/authenticator';
import { unavailableAuthenticator } from '../auth/authenticator';
import { requirePrincipal, requireRole, requireOwnedShop } from '../policy/access';
import { createShop, shopJson, shopSummary } from '../shop/service';
import { ownQr, rotateQr } from '../qr/service';
import { logRequest, type RequestLogger } from '../telemetry/request-event';
import { errorResponse, HttpError, jsonResponse } from './errors';
import { googleExchangeSchema, refreshSchema, logoutSchema, readJson, idSchema } from './schemas';
import type { GoogleIdentity } from '../auth/google';
import type { SessionService } from '../auth/sessions';
import { z } from 'zod';

interface Route {
  path: string;
  method: string;
  handler: (request: Request, requestId: string) => Promise<Response>;
}

export function createApp(options: { db?:D1Database; authenticate?: Authenticator; logger?: RequestLogger; sessions?:SessionService; verifyGoogle?:(token:string)=>Promise<GoogleIdentity> } = {}) {
  const token=(request:Request)=>request.headers.get('Authorization')?.match(/^Bearer ([0-9a-f]{64})$/)?.[1]??'';
  const authenticate = options.sessions ? (request:Request)=>options.sessions!.authenticate(token(request)) : options.authenticate ?? unavailableAuthenticator;
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
      if(options.sessions) {
        const profile=await options.sessions.profile(token(request));
        return jsonResponse({...profile,...(options.db?await shopSummary(options.db,requirePrincipal(await authenticate(request))):{})},requestId);
      }
      requirePrincipal(await authenticate(request));
      return unavailable();
    } },
    { path:'/v1/shops',method:'POST',handler:async(request,requestId)=>{
      const principal=requireRole(await authenticate(request),'owner');
      const schema=z.object({name:z.string().transform(name=>name.normalize('NFC').trim().replace(/\s+/gu,' ')).pipe(z.string().min(1).max(120))}).strict();
      const body=await readJson(request,schema) as z.infer<typeof schema>;
      if(!options.db) return unavailable();
      const result=await createShop(options.db,principal,body.name);
      return jsonResponse(result.shop,requestId,result.created?201:200);
    }},
    {path:'/v1/shops/{shopId}',method:'GET',handler:async(request,requestId)=>{
      const principal=requirePrincipal(await authenticate(request));
      const parsed=idSchema.safeParse(new URL(request.url).pathname.split('/')[3]);
      if(!parsed.success) throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
      if(!options.db) return unavailable();
      return jsonResponse(shopJson(await requireOwnedShop(options.db,principal,parsed.data)),requestId);
    }},
    {path:'/v1/me/qr',method:'GET',handler:async(request,requestId)=>{
      const principal=requireRole(await authenticate(request),'customer');
      if(!options.db) return unavailable();
      return jsonResponse(await ownQr(options.db,principal.userId),requestId);
    }},
    {path:'/v1/me/qr/rotate',method:'POST',handler:async(request,requestId)=>{
      const principal=requireRole(await authenticate(request),'customer');
      await readJson(request,z.object({}).strict());
      if(!options.db || !options.sessions) return unavailable();
      await options.sessions.rateLimit(principal.userId,'qr-rotate');
      return jsonResponse(await rotateQr(options.db,principal.userId),requestId);
    }},
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
        const matching = routes.filter((route) => route.path === path || (route.path==='/v1/shops/{shopId}' && /^\/v1\/shops\/[^/]+$/.test(path)));
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
