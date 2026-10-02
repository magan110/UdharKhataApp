import type {Principal} from '../auth/authenticator';
import {HttpError} from '../http/errors';
import {cursorSchema} from '../http/schemas';
import {decodeCursor,encodeCursor,firstCursor,type ReadCursor} from '../http/cursors';
import {requireRelationship} from '../policy/access';
import {readBalance} from './commands';

interface SyncEntryRow {id:string;server_seq:number;shop_id:string;shop_customer_id:string;client_operation_id:string;kind:string;amount_paise:number|null;target_amount_paise:number|null;effect_paise:number;note:string|null;payment_method:string|null;due_date:string|null;corrects_entry_id:string|null;expected_revision:number|null;correction_reason:string|null;occurred_at_ms:number;created_at_ms:number;created_by_user_id:string}
interface SyncLinkRow {id:string;shop_id:string;customer_user_id:string;owner_user_id:string;display_name:string;nickname:string|null;linked_at_ms:number;status:'active'}
const entryJson=(e:SyncEntryRow)=>({id:e.id,serverSeq:e.server_seq,shopId:e.shop_id,linkId:e.shop_customer_id,clientOperationId:e.client_operation_id,kind:e.kind,amountPaise:e.amount_paise,targetAmountPaise:e.target_amount_paise,effectPaise:e.effect_paise,note:e.note,paymentMethod:e.payment_method,dueDate:e.due_date,correctsEntryId:e.corrects_entry_id,revision:e.expected_revision===null?0:e.expected_revision+1,correctionReason:e.correction_reason,occurredAtMs:e.occurred_at_ms,createdAtMs:e.created_at_ms,createdByUserId:e.created_by_user_id});
export interface SyncPageResponse {items:ReturnType<typeof entryJson>[];link:{id:string;shopId:string;customerUserId:string;ownerUserId:string;displayName:string;nickname:string|null;linkedAtMs:number;status:'active'};nextCursor:string|null;hasMore:boolean;snapshotAtMs:number;highWaterSeq:number;appliedThroughSeq:number;balance:{balancePaise:number;ledgerVersion:number;asOfServerSeq:number;asOfAtMs:number}}
const invalid=()=>new HttpError(409,'CURSOR_INVALID','api.cursorInvalid');
function query(request:Request){
 const params=new URL(request.url).searchParams;
 for(const key of params.keys())if(!['limit','cursor','afterSeq'].includes(key)||params.getAll(key).length!==1)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
 const limit=params.get('limit')??'50',after=params.get('afterSeq')??'0',cursor=params.get('cursor');
 if(!/^[1-9][0-9]*$/.test(limit)||Number(limit)>100||! /^(0|[1-9][0-9]*)$/.test(after)||!Number.isSafeInteger(Number(after))|| (cursor!==null&&(params.has('afterSeq')||!cursorSchema.safeParse(cursor).success)))throw new HttpError(400,'VALIDATION_ERROR','api.validationError');
 return {limit:Number(limit),after:Number(after),cursor};
}
const authorized=`FROM shop_customers l JOIN shops s ON s.id=l.shop_id JOIN users c ON c.id=l.customer_user_id JOIN users o ON o.id=s.owner_user_id
 WHERE l.id=? AND l.shop_id=? AND s.owner_user_id=? AND l.status='active' AND s.status='active' AND c.deleted_at_ms IS NULL AND o.deleted_at_ms IS NULL AND c.account_role='customer' AND o.account_role='owner'`;
export async function readSync(db:D1Database,principal:Principal,shopId:string,linkId:string,request:Request):Promise<SyncPageResponse>{
 await requireRelationship(db,principal,shopId,linkId);
 const q=query(request),scope=JSON.stringify([principal.userId,principal.role,'sync',shopId,linkId]);
 const cursor:ReadCursor=q.cursor?await decodeCursor(db,q.cursor,scope):{...firstCursor(scope,(await readBalance(db,principal,shopId,linkId)).asOfServerSeq,q.after),syncStart:q.after};
 if(typeof cursor.after!=='number'||cursor.syncStart===undefined||cursor.after<cursor.syncStart||cursor.after>cursor.high)throw invalid();
 const args=[linkId,shopId,principal.userId];
 const results=await db.batch([
  db.prepare('SELECT l.id,l.shop_id,l.customer_user_id,s.owner_user_id,c.display_name,l.shop_nickname AS nickname,l.linked_at_ms,l.status '+authorized).bind(...args),
  db.prepare(`SELECT COALESCE(SUM(effect_paise),0) AS balance,COUNT(*) AS version,COALESCE(MAX(server_seq),0) AS seq,MAX(created_at_ms) AS at FROM ledger_entries WHERE shop_customer_id=? AND server_seq<=? AND EXISTS(SELECT 1 ${authorized})`).bind(linkId,cursor.high,...args),
  db.prepare(`SELECT * FROM ledger_entries WHERE shop_customer_id=? AND shop_id=? AND server_seq>? AND server_seq<=? AND EXISTS(SELECT 1 ${authorized}) ORDER BY server_seq LIMIT ?`).bind(linkId,shopId,cursor.after,cursor.high,...args,q.limit+1),
 ]);
 if(!results[0].results.length)throw new HttpError(404,'NOT_FOUND','api.notFound');
 const link=results[0].results[0] as unknown as SyncLinkRow;
 const balance=results[1].results[0] as unknown as {balance:number;version:number;seq:number;at:number|null};
 if(!Number.isSafeInteger(balance.balance))throw new HttpError(503,'CAPACITY_UNAVAILABLE','api.capacityUnavailable',true);
 const rows=results[2].results as unknown as SyncEntryRow[],items=rows.slice(0,q.limit),hasMore=rows.length>q.limit,appliedThroughSeq=items.at(-1)?.server_seq??cursor.after;
 return {items:items.map(entryJson),link:{id:link.id,shopId:link.shop_id,customerUserId:link.customer_user_id,ownerUserId:link.owner_user_id,displayName:link.display_name,nickname:link.nickname,linkedAtMs:link.linked_at_ms,status:link.status},nextCursor:hasMore?await encodeCursor(db,{...cursor,after:appliedThroughSeq}):null,hasMore,snapshotAtMs:cursor.snapshotAtMs,highWaterSeq:cursor.high,appliedThroughSeq,balance:{balancePaise:balance.balance,ledgerVersion:balance.version,asOfServerSeq:balance.seq,asOfAtMs:balance.at??link.linked_at_ms}};
}
