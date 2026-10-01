import type { Principal } from '../auth/authenticator';
import { hashToken } from '../auth/sessions';
import { HttpError } from '../http/errors';
import { requireOwnedShop } from '../policy/access';
import { activeQrCustomer } from '../qr/service';

export interface LinkCommand { clientOperationId:string; publicQrId:string; shopNickname:string|null }
interface LinkRow {
  id:string;shop_id:string;customer_user_id:string;display_name:string;shop_nickname:string|null;
  status:string;linked_at_ms:number;balance_paise:number;version:number;
}
interface Receipt { request_hash:string;operation_kind:string;shop_customer_id:string|null;response_version:number|null;response_balance_paise:number|null }
const linkColumns = `SELECT l.*,u.display_name,a.balance_paise,a.version FROM shop_customers l
 JOIN users u ON u.id=l.customer_user_id JOIN ledger_accounts a ON a.shop_customer_id=l.id
 JOIN shops s ON s.id=l.shop_id JOIN users o ON o.id=s.owner_user_id
 WHERE l.shop_id=? AND l.status='active' AND u.deleted_at_ms IS NULL AND u.account_role='customer'
 AND s.owner_user_id=? AND s.status='active' AND o.deleted_at_ms IS NULL AND o.account_role='owner'`;
const linkJson = (row:LinkRow) => ({id:row.id,shopId:row.shop_id,customerUserId:row.customer_user_id,
 customerDisplayName:row.display_name,shopNickname:row.shop_nickname,status:row.status,
 linkedAtMs:row.linked_at_ms,balancePaise:row.balance_paise,ledgerVersion:row.version});
const missing=()=>new HttpError(404,'NOT_FOUND','api.notFound');
export async function readLink(db:D1Database,principal:Principal,shopId:string,linkId:string) {
 await requireOwnedShop(db,principal,shopId);
 const row=await db.prepare(linkColumns+' AND l.id=?').bind(shopId,principal.userId,linkId).first<LinkRow>();
 if(!row) throw missing();
 return linkJson(row);
}
export async function listLinks(db:D1Database,principal:Principal,shopId:string) {
 await requireOwnedShop(db,principal,shopId);
 const rows=await db.prepare(linkColumns+' ORDER BY l.id LIMIT 101').bind(shopId,principal.userId).all<LinkRow>();
 return {customers:rows.results.slice(0,100).map(linkJson),hasMore:rows.results.length>100};
}
export async function linkCustomer(db:D1Database,principal:Principal,shopId:string,command:LinkCommand) {
 await requireOwnedShop(db,principal,shopId);
 const requestHash=await hashToken(JSON.stringify([principal.userId,shopId,'link',command.publicQrId,command.shopNickname]));
 const receipt=()=>db.prepare('SELECT request_hash,operation_kind,shop_customer_id,response_version,response_balance_paise FROM sync_operations WHERE shop_id=? AND client_operation_id=?').bind(shopId,command.clientOperationId).first<Receipt>();
 const recover=async(row:Receipt)=>{
   if(row.request_hash!==requestHash || row.operation_kind!=='link' || !row.shop_customer_id) throw new HttpError(409,'IDEMPOTENCY_CONFLICT','api.idempotencyConflict');
   const link=await readLink(db,principal,shopId,row.shop_customer_id);
   return {link:{...link,balancePaise:row.response_balance_paise??link.balancePaise,ledgerVersion:row.response_version??link.ledgerVersion},created:false};
 };
 const existing=await receipt();
 if(existing) return recover(existing);
 const customerId=await activeQrCustomer(db,command.publicQrId);
 const id=crypto.randomUUID(),now=Date.now();
 // Every insert uses the live shop/owner/customer/QR predicate inside the atomic batch.
 const guard=`SELECT 1 FROM shops s JOIN users o ON o.id=s.owner_user_id
   JOIN customer_qr_ids q ON q.public_id=? JOIN users c ON c.id=q.customer_user_id
   WHERE s.id=? AND s.owner_user_id=? AND s.status='active' AND o.account_role='owner' AND o.deleted_at_ms IS NULL
   AND q.status='active' AND q.customer_user_id=? AND c.account_role='customer' AND c.deleted_at_ms IS NULL`;
 let created:boolean;
 try {
   const results=await db.batch([
     db.prepare(`INSERT INTO shop_customers(id,shop_id,customer_user_id,shop_nickname,status,linked_at_ms)
       SELECT ?,?,?,?,'active',? WHERE EXISTS(${guard})
       AND NOT EXISTS(SELECT 1 FROM sync_operations WHERE shop_id=? AND client_operation_id=?)
       ON CONFLICT(shop_id,customer_user_id) DO NOTHING RETURNING id`)
       .bind(id,shopId,customerId,command.shopNickname,now,command.publicQrId,shopId,principal.userId,customerId,shopId,command.clientOperationId),
     db.prepare(`INSERT INTO sync_operations(shop_id,client_operation_id,operation_kind,request_hash,shop_customer_id,response_version,response_balance_paise,created_at_ms)
       SELECT ?,?,'link',?,l.id,a.version,a.balance_paise,? FROM shop_customers l JOIN ledger_accounts a ON a.shop_customer_id=l.id
       WHERE l.shop_id=? AND l.customer_user_id=? AND l.status='active' AND EXISTS(${guard})`)
       .bind(shopId,command.clientOperationId,requestHash,now,shopId,customerId,command.publicQrId,shopId,principal.userId,customerId),
     // Missing authorized receipt deliberately violates the link receipt constraint to roll the batch back.
     db.prepare(`INSERT INTO sync_operations(shop_id,client_operation_id,operation_kind,request_hash,created_at_ms)
       SELECT ?,?,'link',?,? WHERE NOT EXISTS(SELECT 1 FROM sync_operations WHERE shop_id=? AND client_operation_id=?)`)
       .bind(shopId,command.clientOperationId,requestHash,now,shopId,command.clientOperationId),
   ]);
   created=results[0].results.length===1;
 } catch(error) {
   const concurrent=await receipt();
   if(concurrent) return recover(concurrent);
   await requireOwnedShop(db,principal,shopId);
   await activeQrCustomer(db,command.publicQrId);
   const removed=await db.prepare("SELECT id FROM shop_customers WHERE shop_id=? AND customer_user_id=? AND status!='active'").bind(shopId,customerId).first();
   if(removed) throw missing();
   throw error;
 }
 const committed=await receipt();
 if(!committed) throw new Error('RECEIPT_MISSING');
 return {...await recover(committed),created};
}
