import type {Principal} from '../auth/authenticator';
import {HttpError} from '../http/errors';
import {requireOwnedShop,requireRelationship} from '../policy/access';
export type RequestKind='export'|'account_deletion'|'shop_deletion'|'access_removal';
interface Row {id:string;request_kind:RequestKind;scope_shop_id:string|null;status:string;created_at_ms:number;resolved_at_ms:number|null}
export const requestJson=(r:Row)=>({id:r.id,kind:r.request_kind,shopId:r.scope_shop_id,status:r.status,createdAtMs:r.created_at_ms,resolvedAtMs:r.resolved_at_ms});
export async function listRequests(db:D1Database,p:Principal){const r=await db.prepare('SELECT * FROM data_requests WHERE requester_user_id=? ORDER BY created_at_ms DESC,id LIMIT 101').bind(p.userId).all<Row>();return {requests:r.results.slice(0,100).map(requestJson),hasMore:r.results.length>100};}
export async function validateScope(db:D1Database,p:Principal,kind:RequestKind,shopId?:string){
 if(kind==='account_deletion'){if(shopId)throw new HttpError(400,'VALIDATION_ERROR','api.validationError');return;}
 if(kind==='shop_deletion'&&p.role!=='owner'||kind==='access_removal'&&p.role!=='customer')throw new HttpError(403,'FORBIDDEN','auth.forbidden');
 if(!shopId){if(kind==='export'&&p.role==='customer')return;throw new HttpError(400,'VALIDATION_ERROR','api.validationError');}
 if(p.role==='owner'){await requireOwnedShop(db,p,shopId);return;}
 const l=await db.prepare("SELECT id FROM shop_customers WHERE shop_id=? AND customer_user_id=? AND status='active'").bind(shopId,p.userId).first<{id:string}>();if(!l)throw new HttpError(404,'NOT_FOUND','api.notFound');await requireRelationship(db,p,shopId,l.id);
}
export async function createRequest(db:D1Database,p:Principal,kind:RequestKind,shopId?:string){
 await validateScope(db,p,kind,shopId);const id=crypto.randomUUID(),now=Date.now();
 const guard=shopId?(p.role==='owner'?"EXISTS(SELECT 1 FROM shops s JOIN users u ON u.id=s.owner_user_id WHERE s.id=? AND s.owner_user_id=? AND s.status='active' AND u.deleted_at_ms IS NULL)":"EXISTS(SELECT 1 FROM shop_customers l JOIN shops s ON s.id=l.shop_id JOIN users o ON o.id=s.owner_user_id WHERE l.shop_id=? AND l.customer_user_id=? AND l.status='active' AND s.status='active' AND o.deleted_at_ms IS NULL)"):'1=1';
 await db.prepare(`INSERT INTO data_requests(id,requester_user_id,request_kind,scope_shop_id,status,created_at_ms) SELECT ?,?,?,?,'submitted',? WHERE EXISTS(SELECT 1 FROM users WHERE id=? AND account_role=? AND deleted_at_ms IS NULL) AND ${guard}`).bind(id,p.userId,kind,shopId??null,now,p.userId,p.role,...(shopId?[shopId,p.userId]:[])).run();
 const row=await db.prepare('SELECT * FROM data_requests WHERE id=?').bind(id).first<Row>();if(!row)throw new HttpError(404,'NOT_FOUND','api.notFound');return requestJson(row);
}
