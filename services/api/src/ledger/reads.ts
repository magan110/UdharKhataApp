import type {Principal} from '../auth/authenticator';
import {HttpError} from '../http/errors';
import {decodeCursor,firstCursor,nextPage,pageQuery} from '../http/cursors';
import {requireOwnedShop,requireRelationship} from '../policy/access';
import {readBalance} from './commands';
import {linkColumns,linkJson,type LinkRow} from './link';
const missing=()=>new HttpError(404,'NOT_FOUND','api.notFound');
const scope=(principal:Principal,route:string,shop='',link='')=>JSON.stringify([principal.userId,principal.role,route,shop,link]);
const authorized=`FROM shop_customers l JOIN shops s ON s.id=l.shop_id
 JOIN users c ON c.id=l.customer_user_id JOIN users o ON o.id=s.owner_user_id
 WHERE l.id=? AND l.shop_id=? AND l.status='active' AND s.status='active'
 AND c.deleted_at_ms IS NULL AND o.deleted_at_ms IS NULL AND c.account_role='customer' AND o.account_role='owner'
 AND ((?='owner' AND s.owner_user_id=?) OR (?='customer' AND l.customer_user_id=?))`;
interface EntryRow {id:string;server_seq:number;shop_id:string;shop_customer_id:string;kind:string;amount_paise:number|null;target_amount_paise:number|null;effect_paise:number;note:string|null;payment_method:string|null;due_date:string|null;corrects_entry_id:string|null;expected_revision:number|null;correction_reason:string|null;occurred_at_ms:number;created_at_ms:number;created_by_user_id:string}
const entryJson=(e:EntryRow)=>({id:e.id,serverSeq:e.server_seq,shopId:e.shop_id,linkId:e.shop_customer_id,kind:e.kind,amountPaise:e.amount_paise,targetAmountPaise:e.target_amount_paise,effectPaise:e.effect_paise,note:e.note,paymentMethod:e.payment_method,dueDate:e.due_date,correctsEntryId:e.corrects_entry_id,revision:e.expected_revision===null?0:e.expected_revision+1,correctionReason:e.correction_reason,occurredAtMs:e.occurred_at_ms,createdAtMs:e.created_at_ms,createdByUserId:e.created_by_user_id});
export async function readEntries(db:D1Database,principal:Principal,shopId:string,linkId:string,request:Request){
 await requireRelationship(db,principal,shopId,linkId);
 const query=pageQuery(request),bound=scope(principal,'entries',shopId,linkId);
 const cursor=query.cursor?await decodeCursor(db,query.cursor,bound):firstCursor(bound,(await readBalance(db,principal,shopId,linkId)).asOfServerSeq,0);
 if(typeof cursor.after!=='number'||cursor.after>cursor.high)throw new HttpError(409,'CURSOR_INVALID','api.cursorInvalid');
 const args=[linkId,shopId,principal.role,principal.userId,principal.role,principal.userId];
 // All statements execute in one D1 batch snapshot. Live access is required even on continuation.
 const result=await db.batch([
  db.prepare('SELECT l.id,l.linked_at_ms,s.name AS shop_name,c.display_name '+authorized).bind(...args),
  db.prepare(`SELECT COALESCE(SUM(effect_paise),0) AS balance,COUNT(*) AS version,COALESCE(MAX(server_seq),0) AS seq,MAX(created_at_ms) AS at FROM ledger_entries WHERE shop_customer_id=? AND server_seq<=? AND EXISTS(SELECT 1 ${authorized})`).bind(linkId,cursor.high,...args),
  db.prepare(`SELECT * FROM ledger_entries WHERE shop_customer_id=? AND shop_id=? AND server_seq>? AND server_seq<=? AND EXISTS(SELECT 1 ${authorized}) ORDER BY server_seq LIMIT ?`).bind(linkId,shopId,cursor.after,cursor.high,...args,query.limit+1),
 ]);
 if(!result[0].results.length)throw missing();
 const balance=result[1].results[0] as unknown as {balance:number;version:number;seq:number;at:number|null};
 const rows=result[2].results as unknown as EntryRow[],entries=rows.slice(0,query.limit);
 const identity=result[0].results[0] as {shop_name:string;display_name:string;linked_at_ms:number};
 return {shopId,linkId,shopName:identity.shop_name,customerDisplayName:identity.display_name,entries:entries.map(entryJson),balance:{balancePaise:balance.balance,ledgerVersion:balance.version,asOfServerSeq:balance.seq,asOfAtMs:balance.at??identity.linked_at_ms},snapshotAtMs:cursor.snapshotAtMs,page:await nextPage(db,cursor,entries.at(-1)?.server_seq??cursor.after,rows.length>query.limit)};
}
export async function pagedLinks(db:D1Database,principal:Principal,shopId:string,request:Request){
 await requireOwnedShop(db,principal,shopId);
 const query=pageQuery(request),bound=scope(principal,'customers',shopId);
 const high=async()=>await db.prepare('SELECT COALESCE(MAX(rowid),0) AS high FROM shop_customers WHERE shop_id=?').bind(shopId).first<number>('high')??0;
 const cursor=query.cursor?await decodeCursor(db,query.cursor,bound):firstCursor(bound,await high(),'');
 if(typeof cursor.after!=='string')throw new HttpError(409,'CURSOR_INVALID','api.cursorInvalid');
 const result=await db.batch([
  db.prepare("SELECT s.id FROM shops s JOIN users o ON o.id=s.owner_user_id WHERE s.id=? AND s.owner_user_id=? AND s.status='active' AND o.deleted_at_ms IS NULL").bind(shopId,principal.userId),
  db.prepare(linkColumns+' AND l.rowid<=? AND l.id>? ORDER BY l.id LIMIT ?').bind(shopId,principal.userId,cursor.high,cursor.after,query.limit+1),
 ]);
 if(!result[0].results.length)throw missing();
 const rows=result[1].results as unknown as LinkRow[],customers=rows.slice(0,query.limit).map(linkJson),hasMore=rows.length>query.limit;
 return {customers,hasMore,snapshotAtMs:cursor.snapshotAtMs,page:await nextPage(db,cursor,customers.at(-1)?.id??cursor.after,hasMore)};
}
const customerLinks=`FROM shop_customers l JOIN ledger_accounts a ON a.shop_customer_id=l.id JOIN shops s ON s.id=l.shop_id JOIN users o ON o.id=s.owner_user_id JOIN users c ON c.id=l.customer_user_id WHERE l.customer_user_id=? AND l.status='active' AND s.status='active' AND o.deleted_at_ms IS NULL AND o.account_role='owner' AND c.deleted_at_ms IS NULL AND c.account_role='customer'`;
interface ShopLinkRow {id:string;shop_id:string;name:string;balance_paise:number;version:number}
export async function ownLedgers(db:D1Database,principal:Principal,request:Request){
 const query=pageQuery(request),bound=scope(principal,'ledgers');
 const high=async()=>await db.prepare('SELECT COALESCE(MAX(l.rowid),0) AS high '+customerLinks).bind(principal.userId).first<number>('high')??0;
 const cursor=query.cursor?await decodeCursor(db,query.cursor,bound):firstCursor(bound,await high(),'');
 if(typeof cursor.after!=='string')throw new HttpError(409,'CURSOR_INVALID','api.cursorInvalid');
 const result=await db.batch([
  db.prepare("SELECT id FROM users WHERE id=? AND account_role='customer' AND deleted_at_ms IS NULL").bind(principal.userId),
  db.prepare('SELECT l.id,l.shop_id,s.name,a.balance_paise,a.version '+customerLinks+' AND l.rowid<=? AND l.id>? ORDER BY l.id LIMIT ?').bind(principal.userId,cursor.high,cursor.after,query.limit+1),
 ]);
 if(!result[0].results.length)throw missing();
 const rows=result[1].results as unknown as ShopLinkRow[],links=rows.slice(0,query.limit).map(r=>({id:r.id,shopId:r.shop_id,shopName:r.name,balancePaise:r.balance_paise,ledgerVersion:r.version}));
 return {links,snapshotAtMs:cursor.snapshotAtMs,page:await nextPage(db,cursor,links.at(-1)?.id??cursor.after,rows.length>query.limit)};
}
export async function totals(db:D1Database,principal:Principal,shopId:string){
 await requireOwnedShop(db,principal,shopId);
 const row=await db.prepare(`SELECT s.id,s.name,s.status,s.created_at_ms,COALESCE(SUM(a.balance_paise),0) AS total,COUNT(l.id) AS count,COALESCE(MAX(a.updated_at_ms),s.created_at_ms) AS at
 FROM shops s JOIN users o ON o.id=s.owner_user_id LEFT JOIN shop_customers l ON l.shop_id=s.id LEFT JOIN ledger_accounts a ON a.shop_customer_id=l.id
 WHERE s.id=? AND s.owner_user_id=? AND s.status='active' AND o.deleted_at_ms IS NULL GROUP BY s.id`).bind(shopId,principal.userId).first<{id:string;name:string;status:string;created_at_ms:number;total:number;count:number;at:number}>();
 if(!row)throw missing();
 if(!Number.isSafeInteger(row.total))throw new HttpError(503,'CAPACITY_UNAVAILABLE','api.capacityUnavailable',true);
 return {id:row.id,name:row.name,status:row.status,createdAtMs:row.created_at_ms,totalBalancePaise:row.total,customerCount:row.count,asOfAtMs:row.at};
}
