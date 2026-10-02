import type {Principal} from '../auth/authenticator';
import {HttpError} from '../http/errors';
import {requireRelationship} from '../policy/access';
import {allocateLedger,type AllocationEntry} from './allocation';
export async function readDue(db:D1Database,principal:Principal,shopId:string,linkId:string,asOfDate:string){
 await requireRelationship(db,principal,shopId,linkId);
 const access=`FROM shop_customers l JOIN shops s ON s.id=l.shop_id JOIN users c ON c.id=l.customer_user_id JOIN users o ON o.id=s.owner_user_id WHERE l.id=? AND l.shop_id=? AND l.status='active' AND s.status='active' AND c.deleted_at_ms IS NULL AND o.deleted_at_ms IS NULL AND ((?='owner' AND s.owner_user_id=?) OR (?='customer' AND l.customer_user_id=?))`;
 const args=[linkId,shopId,principal.role,principal.userId,principal.role,principal.userId];
 const result=await db.batch([db.prepare('SELECT l.id,l.linked_at_ms '+access).bind(...args),db.prepare(`SELECT id,server_seq AS serverSeq,kind,amount_paise AS amountPaise,target_amount_paise AS targetAmountPaise,corrects_entry_id AS correctsEntryId,due_date AS dueDate,created_at_ms AS createdAtMs FROM ledger_entries WHERE shop_customer_id=? AND shop_id=? AND EXISTS(SELECT 1 ${access}) ORDER BY server_seq`).bind(linkId,shopId,...args)]);
 if(!result[0].results.length)throw new HttpError(404,'NOT_FOUND','api.notFound');
 const rows=result[1].results as unknown as (AllocationEntry&{createdAtMs:number})[];
 const {balancePaise,overduePaise}=allocateLedger(rows,asOfDate);
 return {asOfDate,balancePaise,overduePaise,asOfServerSeq:rows.at(-1)?.serverSeq??0,asOfMs:Date.now()};
}
