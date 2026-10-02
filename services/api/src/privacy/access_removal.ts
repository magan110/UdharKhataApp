import type {Principal} from '../auth/authenticator';
import {HttpError} from '../http/errors';
import {requestJson} from './requests';
export async function removeAccess(db:D1Database,p:Principal,shopId:string){
 if(p.role!=='customer')throw new HttpError(403,'FORBIDDEN','auth.forbidden');
 const guard="SELECT 1 FROM shop_customers l JOIN shops s ON s.id=l.shop_id JOIN users c ON c.id=l.customer_user_id JOIN users o ON o.id=s.owner_user_id WHERE l.shop_id=? AND l.customer_user_id=? AND s.status='active' AND c.deleted_at_ms IS NULL AND o.deleted_at_ms IS NULL";
 if(!await db.prepare(guard).bind(shopId,p.userId).first())throw new HttpError(404,'NOT_FOUND','api.notFound');
 const id=crypto.randomUUID(),now=Date.now();
 await db.batch([
 db.prepare(`INSERT INTO data_requests(id,requester_user_id,request_kind,scope_shop_id,status,created_at_ms,resolved_at_ms) SELECT ?,?,'access_removal',?,'completed',?,? WHERE EXISTS(${guard} AND l.status='active')`).bind(id,p.userId,shopId,now,now,shopId,p.userId),
 db.prepare(`UPDATE shop_customers SET status='access_removed',access_removed_at_ms=? WHERE shop_id=? AND customer_user_id=? AND status='active' AND EXISTS(SELECT 1 FROM data_requests WHERE id=?)`).bind(now,shopId,p.userId,id),
 ]);
 const row=await db.prepare("SELECT * FROM data_requests WHERE requester_user_id=? AND scope_shop_id=? AND request_kind='access_removal' AND status='completed' ORDER BY created_at_ms DESC,id DESC LIMIT 1").bind(p.userId,shopId).first<Parameters<typeof requestJson>[0]>();if(!row)throw new HttpError(404,'NOT_FOUND','api.notFound');
 return {shopId,status:'access_removed',request:requestJson(row)};
}
