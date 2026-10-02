import {z} from 'zod';
import type {Authenticator} from '../auth/authenticator';
import type {SessionService} from '../auth/sessions';
import {HttpError,jsonResponse} from '../http/errors';
import {idSchema,readJson} from '../http/schemas';
import {requirePrincipal,requireRole} from '../policy/access';
import {createRequest,listRequests,type RequestKind} from './requests';
import {removeAccess} from './access_removal';
export function privacyRoutes(o:{db?:D1Database;authenticate:Authenticator;sessions?:SessionService}){
 const db=()=>{if(!o.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);return o.db;};
 return [
 {path:'/v1/me/data-requests',method:'GET',handler:async(r:Request,rid:string)=>{const p=requirePrincipal(await o.authenticate(r));return jsonResponse(await listRequests(db(),p),rid);}},
 {path:'/v1/me/data-requests',method:'POST',handler:async(r:Request,rid:string)=>{const p=requirePrincipal(await o.authenticate(r));const b=await readJson(r,z.object({kind:z.enum(['export','account_deletion','shop_deletion','access_removal']),shopId:idSchema.optional()}).strict()) as {kind:RequestKind;shopId?:string};if(o.sessions)await o.sessions.rateLimit(p.userId,'privacy-request');return jsonResponse(await createRequest(db(),p,b.kind,b.shopId),rid,202);}},
 {path:'/v1/me/ledgers/{shopId}/access-removal',method:'POST',handler:async(r:Request,rid:string)=>{const p=requireRole(await o.authenticate(r),'customer');await readJson(r,z.object({}).strict());const shop=idSchema.safeParse(new URL(r.url).pathname.split('/')[4]);if(!shop.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');if(o.sessions)await o.sessions.rateLimit(p.userId,'privacy-request');return jsonResponse(await removeAccess(db(),p,shop.data),rid);}},
 ];
}
