import {z} from 'zod';
import type {Authenticator} from '../auth/authenticator';
import type {SessionService} from '../auth/sessions';
import {postCredit,readBalance,type CreditCommand} from '../ledger/commands';
import {CREDIT_LIMITS} from '../ledger/limits';
import {requireRole} from '../policy/access';
import {HttpError,jsonResponse} from './errors';
import {idSchema,readJson,timestampMsSchema} from './schemas';
const dateSchema=z.string().length(10).regex(/^\d{4}-\d{2}-\d{2}$/).refine(s=>{
 const date=new Date(s+'T00:00:00Z');return Number.isFinite(date.getTime())&&date.toISOString().slice(0,10)===s;
});
export const creditSchema=z.object({
 clientOperationId:z.string().length(36).regex(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/),
 linkId:idSchema,kind:z.literal('credit'),amountPaise:z.number().int().min(1).max(CREDIT_LIMITS.maxAmountPaise),
 note:z.string().transform(s=>s.trim()).pipe(z.string().max(CREDIT_LIMITS.maxNoteCharacters)).nullable().optional().transform(s=>s||null),
 dueDate:dateSchema.nullable().optional().transform(s=>s??null),occurredAtMs:timestampMsSchema,
}).strict();
function pathId(value:string){const parsed=idSchema.safeParse(value);if(!parsed.success)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return parsed.data;}
export function ledgerRoutes(options:{db?:D1Database;authenticate:Authenticator;sessions?:SessionService}){
 return [{path:'/v1/shops/{shopId}/entries',method:'POST',handler:async(request:Request,requestId:string)=>{
  const principal=requireRole(await options.authenticate(request),'owner');
  if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);
  const shopId=pathId(new URL(request.url).pathname.split('/')[3]);
  const body=await readJson(request,creditSchema,CREDIT_LIMITS.maxBodyBytes) as CreditCommand;
  if(options.sessions)await options.sessions.rateLimit(principal.userId,'entry-owner');
  const result=await postCredit(options.db,principal,shopId,body);
  return jsonResponse(result,requestId,result.replayed?200:201);
 }},{path:'/v1/shops/{shopId}/customers/{linkId}/balance',method:'GET',handler:async(request:Request,requestId:string)=>{
  const principal=requireRole(await options.authenticate(request),'owner');
  if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);
  const parts=new URL(request.url).pathname.split('/');
  return jsonResponse(await readBalance(options.db,principal,pathId(parts[3]),pathId(parts[5])),requestId);
 }},{path:'/v1/me/ledgers/{shopId}/balance',method:'GET',handler:async(request:Request,requestId:string)=>{
  const principal=requireRole(await options.authenticate(request),'customer');
  if(!options.db)throw new HttpError(503,'FEATURE_UNAVAILABLE','api.featureUnavailable',true);
  const shopId=pathId(new URL(request.url).pathname.split('/')[4]);
  const row=await options.db.prepare("SELECT id FROM shop_customers WHERE shop_id=? AND customer_user_id=? AND status='active'").bind(shopId,principal.userId).first<{id:string}>();
  if(!row)throw new HttpError(404,'NOT_FOUND','api.notFound');
  return jsonResponse(await readBalance(options.db,principal,shopId,row.id),requestId);
 }}];
}
