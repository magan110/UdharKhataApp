import { z } from 'zod';
import type { Authenticator } from '../auth/authenticator';
import { SessionService } from '../auth/sessions';
import { requireRole, requireOwnedShop } from '../policy/access';
import { resolveCustomer } from '../qr/resolve';
import { linkCustomer, readLink, listLinks } from '../ledger/link';
import { HttpError, jsonResponse } from './errors';
import { idSchema, readJson } from './schemas';
export const publicQrSchema=z.string().regex(/^[0-9a-f]{64}$/);
export const linkSchema=z.object({
 clientOperationId:z.string().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/),
 publicQrId:publicQrSchema,
 shopNickname:z.string().transform(s=>s.normalize('NFC').trim().replace(/\s+/gu,' ')).pipe(z.string().max(120)).nullable().optional().transform(s=>s||null),
}).strict();
interface Options { db?:D1Database; authenticate:Authenticator; sessions?:SessionService }
const dbRequired=(db?:D1Database)=>{if(!db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);return db;};
const pathId=(text:string)=>{const value=idSchema.safeParse(text);if(!value.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return value.data;};
export function qrRoutes(options:Options) {
 return [
  {path:'/v1/customer-qr/resolve',method:'POST',handler:async(request:Request,requestId:string)=>{
    const principal=requireRole(await options.authenticate(request),'owner');
    const schema=z.object({shopId:idSchema,publicQrId:publicQrSchema}).strict();
    const body=await readJson(request,schema) as z.infer<typeof schema>,db=dbRequired(options.db);
    await requireOwnedShop(db,principal,body.shopId);
    // Independent owner and network buckets; hashes only, never raw identifiers in telemetry.
    const limiter=options.sessions ?? new SessionService(db);
    await limiter.rateLimit(principal.userId,'qr-resolve-owner');
    await limiter.rateLimit(request.headers.get('CF-Connecting-IP')??'unknown','qr-resolve-network');
    return jsonResponse(await resolveCustomer(db,principal,body.shopId,body.publicQrId),requestId);
  }},
  {path:'/v1/shops/{shopId}/customers',method:'POST',handler:async(request:Request,requestId:string)=>{
    const principal=requireRole(await options.authenticate(request),'owner');
    const shopId=pathId(new URL(request.url).pathname.split('/')[3]);
    const body=await readJson(request,linkSchema) as z.infer<typeof linkSchema>;
    const result=await linkCustomer(dbRequired(options.db),principal,shopId,body);
    return jsonResponse(result.link,requestId,result.created?201:200);
  }},
  {path:'/v1/shops/{shopId}/customers',method:'GET',handler:async(request:Request,requestId:string)=>{
    const principal=requireRole(await options.authenticate(request),'owner'),url=new URL(request.url);
    if(url.search)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
    return jsonResponse(await listLinks(dbRequired(options.db),principal,pathId(url.pathname.split('/')[3])),requestId);
  }},
  {path:'/v1/shops/{shopId}/customers/{linkId}',method:'GET',handler:async(request:Request,requestId:string)=>{
    const principal=requireRole(await options.authenticate(request),'owner'),parts=new URL(request.url).pathname.split('/');
    return jsonResponse(await readLink(dbRequired(options.db),principal,pathId(parts[3]),pathId(parts[5])),requestId);
  }},
 ];
}
