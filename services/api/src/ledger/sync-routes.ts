import type {Authenticator} from '../auth/authenticator';
import {requireRole} from '../policy/access';
import {HttpError,jsonResponse} from '../http/errors';
import {idSchema} from '../http/schemas';
import {readSync} from './sync-reads';
export function syncRoutes(options:{db?:D1Database;authenticate:Authenticator}){
 return [{path:'/v1/shops/{shopId}/customers/{linkId}/sync',method:'GET',handler:async(request:Request,id:string)=>{
  const principal=requireRole(await options.authenticate(request),'owner');
  const parts=new URL(request.url).pathname.split('/'),shop=idSchema.safeParse(parts[3]),link=idSchema.safeParse(parts[5]);
  if(!shop.success||!link.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
  if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);
  return jsonResponse(await readSync(options.db,principal,shop.data,link.data,request),id);
 }}];
}
