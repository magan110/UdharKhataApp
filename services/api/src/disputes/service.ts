import type {Principal} from '../auth/authenticator';
import {HttpError} from '../http/errors';
import {requireEntry,requireOwnedShop,requireRelationship} from '../policy/access';
interface Row {id:string;shop_id:string;entry_id:string;customer_user_id:string;status:'open'|'resolved';reason:string;owner_note:string|null;created_at_ms:number;resolved_at_ms:number|null;shop_customer_id:string}
const columns='SELECT d.*,l.shop_id FROM disputes d JOIN shop_customers l ON l.id=d.shop_customer_id';
const json=(r:Row)=>({id:r.id,shopId:r.shop_id,entryId:r.entry_id,customerUserId:r.customer_user_id,status:r.status,reason:r.reason,resolutionNote:r.owner_note,createdAtMs:r.created_at_ms,resolvedAtMs:r.resolved_at_ms});
const missing=()=>new HttpError(404,'NOT_FOUND','api.notFound');
export async function listDisputes(db:D1Database,p:Principal,shopId?:string,before?:string){
 if(p.role==='owner'){if(!shopId)throw missing();await requireOwnedShop(db,p,shopId);}
 if(p.role==='customer'&&shopId){const link=await db.prepare("SELECT id FROM shop_customers WHERE shop_id=? AND customer_user_id=? AND status='active'").bind(shopId,p.userId).first<{id:string}>();if(!link)throw missing();await requireRelationship(db,p,shopId,link.id);}
 const scope=p.role==='owner'?"l.shop_id=? AND EXISTS(SELECT 1 FROM shops s JOIN users o ON o.id=s.owner_user_id WHERE s.id=l.shop_id AND s.owner_user_id=? AND s.status='active' AND o.account_role='owner' AND o.deleted_at_ms IS NULL)":"d.customer_user_id=? AND l.status='active' AND EXISTS(SELECT 1 FROM shops s JOIN users o ON o.id=s.owner_user_id JOIN users c ON c.id=l.customer_user_id WHERE s.id=l.shop_id AND s.status='active' AND o.deleted_at_ms IS NULL AND c.deleted_at_ms IS NULL)";
 const filter=scope+(p.role==='customer'&&shopId?' AND l.shop_id=?':'');
 const bindings=[p.role==='owner'?shopId!:p.userId,...(p.role==='owner'?[p.userId]:[]),...(p.role==='customer'&&shopId?[shopId]:[])];
 let anchor:Row|null=null;
 if(before){anchor=await db.prepare(columns+' WHERE '+filter+' AND d.id=?').bind(...bindings,before).first<Row>();if(!anchor)throw new HttpError(409,'CURSOR_INVALID','api.cursorInvalid');}
 const rows=await db.prepare(columns+' WHERE '+filter+(anchor?' AND (d.created_at_ms<? OR (d.created_at_ms=? AND d.id<?))':'')+' ORDER BY d.created_at_ms DESC,d.id DESC LIMIT 101').bind(...bindings,...(anchor?[anchor.created_at_ms,anchor.created_at_ms,anchor.id]:[])).all<Row>();
 const items=rows.results.slice(0,100);const hasMore=rows.results.length>100;
 return {items:items.map(json),hasMore,nextCursor:hasMore?items[items.length-1].id:null};
}
export async function reportDispute(db:D1Database,p:Principal,shopId:string,entryId:string,reason:string){
 const l=await db.prepare("SELECT id FROM shop_customers WHERE shop_id=? AND customer_user_id=? AND status='active'").bind(shopId,p.userId).first<{id:string}>();if(!l)throw missing();await requireEntry(db,p,shopId,l.id,entryId);
 const id=crypto.randomUUID(),now=Date.now();
 await db.prepare(`INSERT INTO disputes(id,entry_id,shop_customer_id,customer_user_id,reason,status,created_at_ms) SELECT ?,e.id,l.id,? ,?,'open',? FROM ledger_entries e JOIN shop_customers l ON l.id=e.shop_customer_id JOIN shops s ON s.id=l.shop_id JOIN users c ON c.id=l.customer_user_id JOIN users o ON o.id=s.owner_user_id WHERE e.id=? AND e.shop_id=? AND l.customer_user_id=? AND l.status='active' AND s.status='active' AND c.deleted_at_ms IS NULL AND o.deleted_at_ms IS NULL ON CONFLICT DO NOTHING`).bind(id,p.userId,reason,now,entryId,shopId,p.userId).run();
 await requireEntry(db,p,shopId,l.id,entryId);
 const r=await db.prepare(columns+" WHERE d.entry_id=? AND d.customer_user_id=? AND d.status='open'").bind(entryId,p.userId).first<Row>();if(!r)throw missing();return {item:json(r),created:r.id===id};
}
export async function resolveDispute(db:D1Database,p:Principal,shopId:string,id:string,note:string){
 await requireOwnedShop(db,p,shopId);
 const read=()=>db.prepare(columns+' WHERE d.id=? AND l.shop_id=?').bind(id,shopId).first<Row>();
 const row=await read();if(!row)throw missing();
 await db.prepare(`UPDATE disputes SET status='resolved',owner_note=?,resolved_at_ms=?,resolved_by_user_id=? WHERE id=? AND status='open' AND EXISTS(SELECT 1 FROM shop_customers l JOIN shops s ON s.id=l.shop_id JOIN users o ON o.id=s.owner_user_id WHERE l.id=disputes.shop_customer_id AND s.id=? AND s.owner_user_id=? AND s.status='active' AND o.deleted_at_ms IS NULL)`).bind(note,Date.now(),p.userId,id,shopId,p.userId).run();
 await requireOwnedShop(db,p,shopId);const result=await read();if(!result)throw missing();if(result.owner_note!==note)throw new HttpError(409,'REVISION_CONFLICT','api.revisionConflict');return json(result);
}
