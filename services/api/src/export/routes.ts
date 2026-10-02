import type {Authenticator} from '../auth/authenticator';
import type {SessionService} from '../auth/sessions';
import {pageQuery} from '../http/cursors';
import {HttpError,jsonResponse} from '../http/errors';
import {idSchema} from '../http/schemas';
import {readEntries} from '../ledger/reads';
import {requireRelationship,requireRole} from '../policy/access';
function pathId(value:string){const parsed=idSchema.safeParse(value);if(!parsed.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return parsed.data;}
export function exportRoutes(options:{db?:D1Database;authenticate:Authenticator;sessions?:SessionService}){
 return [{path:'/v1/shops/{shopId}/customers/{linkId}/statement',method:'GET',handler:async(request:Request,requestId:string)=>{
  const principal=requireRole(await options.authenticate(request),'owner');
  if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);
  const parts=new URL(request.url).pathname.split('/'),shopId=pathId(parts[3]),linkId=pathId(parts[5]);
  await requireRelationship(options.db,principal,shopId,linkId);
  const query=pageQuery(request);
  // Charge each export start, so a large bounded statement can finish its pages.
  // Continuations still receive normal authenticated owner-read limits and scoped cursor validation.
  if(options.sessions)await options.sessions.rateLimit(principal.userId,query.cursor?'read-owner':'export-owner');
  return jsonResponse(await readEntries(options.db,principal,shopId,linkId,request),requestId);
 }}];
}
