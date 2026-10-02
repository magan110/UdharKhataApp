import type {Authenticator} from '../auth/authenticator';
import {requireRole} from '../policy/access';
import {HttpError,jsonResponse} from '../http/errors';
import {idSchema} from '../http/schemas';
import {ownLedgers,readEntries} from './reads';
const pathId=(value:string)=>{const parsed=idSchema.safeParse(value);if(!parsed.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return parsed.data;};
export function readRoutes(options:{db?:D1Database;authenticate:Authenticator}){
 const db=()=>{if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);return options.db;};
 return [
 {path:'/v1/me/ledgers',method:'GET',handler:async(r:Request,id:string)=>jsonResponse(await ownLedgers(db(),requireRole(await options.authenticate(r),'customer'),r),id)},
 {path:'/v1/shops/{shopId}/customers/{linkId}/entries',method:'GET',handler:async(r:Request,id:string)=>{
  const principal=requireRole(await options.authenticate(r),'owner'),parts=new URL(r.url).pathname.split('/');
  return jsonResponse(await readEntries(db(),principal,pathId(parts[3]),pathId(parts[5]),r),id);
 }},
 {path:'/v1/me/ledgers/{shopId}/entries',method:'GET',handler:async(r:Request,id:string)=>{
  const principal=requireRole(await options.authenticate(r),'customer'),shopId=pathId(new URL(r.url).pathname.split('/')[4]),database=db();
  const row=await database.prepare("SELECT id FROM shop_customers WHERE shop_id=? AND customer_user_id=? AND status='active'").bind(shopId,principal.userId).first<{id:string}>();
  if(!row)throw new HttpError(404,'NOT_FOUND','api.notFound');
  return jsonResponse(await readEntries(database,principal,shopId,row.id,r),id);
 }},
 ];
}
