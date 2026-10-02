import type {SessionService} from '../auth/sessions';
import type {Authenticator} from '../auth/authenticator';
import {HttpError,jsonResponse} from '../http/errors';
import {idSchema} from '../http/schemas';
import {requireRole} from '../policy/access';
import {readDue} from './overdue';
function pathId(value:string){const p=idSchema.safeParse(value);if(!p.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return p.data;}
function asOf(request:Request){const q=new URL(request.url).searchParams;const date=q.get('asOfDate');if([...q.keys()].some(k=>k!=='asOfDate')||q.getAll('asOfDate').length!==1||!date||!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date+'T00:00:00Z'))||new Date(date+'T00:00:00Z').toISOString().slice(0,10)!==date)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return date;}
export function financialRoutes(options:{db?:D1Database;authenticate:Authenticator;sessions?:SessionService}){
 return [{path:'/v1/shops/{shopId}/customers/{linkId}/due',method:'GET',handler:async(request:Request,requestId:string)=>{
 const principal=requireRole(await options.authenticate(request),'owner');if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);const p=new URL(request.url).pathname.split('/');return jsonResponse(await readDue(options.db,principal,pathId(p[3]),pathId(p[5]),asOf(request)),requestId);
 }},{path:'/v1/me/ledgers/{shopId}/due',method:'GET',handler:async(request:Request,requestId:string)=>{
 const principal=requireRole(await options.authenticate(request),'customer');if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);const shopId=pathId(new URL(request.url).pathname.split('/')[4]);const date=asOf(request);const link=await options.db.prepare("SELECT id FROM shop_customers WHERE shop_id=? AND customer_user_id=? AND status='active'").bind(shopId,principal.userId).first<{id:string}>();if(!link)throw new HttpError(404,'NOT_FOUND','api.notFound');return jsonResponse(await readDue(options.db,principal,shopId,link.id,date),requestId);
 }}];
}
