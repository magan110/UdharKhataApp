import {z} from 'zod';
import type {Authenticator} from '../auth/authenticator';
import type {SessionService} from '../auth/sessions';
import {HttpError,jsonResponse} from '../http/errors';
import {idSchema,readJson} from '../http/schemas';
import {requireRole} from '../policy/access';
import {listDisputes,reportDispute,resolveDispute} from './service';
const text=z.string().trim().min(1).max(500);
const id=(s:string)=>{const r=idSchema.safeParse(s);if(!r.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return r.data;};
function query(r:Request,customer:boolean){const u=new URL(r.url);const allowed=customer?['shopId','before']:['before'];if([...u.searchParams.keys()].some(k=>!allowed.includes(k))||allowed.some(k=>u.searchParams.getAll(k).length>1))throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return {shopId:u.searchParams.has('shopId')?id(u.searchParams.get('shopId')!):undefined,before:u.searchParams.has('before')?id(u.searchParams.get('before')!):undefined};}
export function disputeRoutes(o:{db?:D1Database;authenticate:Authenticator;sessions?:SessionService}){
 const db=()=>{if(!o.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);return o.db;};
 return [
 {path:'/v1/shops/{shopId}/disputes',method:'GET',handler:async(r:Request,rid:string)=>{const p=requireRole(await o.authenticate(r),'owner');const q=query(r,false);return jsonResponse(await listDisputes(db(),p,id(new URL(r.url).pathname.split('/')[3]),q.before),rid);}},
 {path:'/v1/me/disputes',method:'GET',handler:async(r:Request,rid:string)=>{const p=requireRole(await o.authenticate(r),'customer');const q=query(r,true);return jsonResponse(await listDisputes(db(),p,q.shopId,q.before),rid);}},
 {path:'/v1/me/ledgers/{shopId}/entries/{entryId}/disputes',method:'POST',handler:async(r:Request,rid:string)=>{const p=requireRole(await o.authenticate(r),'customer');const b=await readJson(r,z.object({reason:text}).strict()) as {reason:string};const parts=new URL(r.url).pathname.split('/');if(o.sessions)await o.sessions.rateLimit(p.userId,'dispute-customer');const result=await reportDispute(db(),p,id(parts[4]),id(parts[6]),b.reason);return jsonResponse(result.item,rid,result.created?201:200);}},
 {path:'/v1/shops/{shopId}/disputes/{disputeId}/resolve',method:'POST',handler:async(r:Request,rid:string)=>{const p=requireRole(await o.authenticate(r),'owner');const b=await readJson(r,z.object({resolutionNote:text}).strict()) as {resolutionNote:string};const parts=new URL(r.url).pathname.split('/');if(o.sessions)await o.sessions.rateLimit(p.userId,'dispute-owner');return jsonResponse(await resolveDispute(db(),p,id(parts[3]),id(parts[5]),b.resolutionNote),rid);}},
 ];
}
