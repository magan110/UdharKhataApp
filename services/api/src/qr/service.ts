import { HttpError } from '../http/errors';

function randomQrId():string {
 return Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
}
const qrJson=(id:string)=>({version:1,publicQrId:id,payload:`udhaar://customer/v1/${id}`});
export async function ownQr(db:D1Database,userId:string,now=Date.now()) {
 await db.prepare("INSERT INTO customer_qr_ids(public_id,customer_user_id,status,created_at_ms) SELECT ?,id,'active',? FROM users WHERE id=? AND account_role='customer' AND deleted_at_ms IS NULL ON CONFLICT DO NOTHING").bind(randomQrId(),now,userId).run();
 const row=await db.prepare("SELECT q.public_id FROM customer_qr_ids q JOIN users u ON u.id=q.customer_user_id WHERE q.customer_user_id=? AND q.status='active' AND u.account_role='customer' AND u.deleted_at_ms IS NULL").bind(userId).first<{public_id:string}>();
 if(!row) throw new HttpError(401,'AUTH_REQUIRED','auth.required');
 return qrJson(row.public_id);
}
export async function rotateQr(db:D1Database,userId:string) {
 const id=randomQrId(),now=Date.now();
 const results=await db.batch([
   db.prepare("UPDATE customer_qr_ids SET status='revoked',revoked_at_ms=? WHERE customer_user_id=? AND status='active' AND EXISTS(SELECT 1 FROM users WHERE id=? AND account_role='customer' AND deleted_at_ms IS NULL)").bind(now,userId,userId),
   db.prepare("INSERT INTO customer_qr_ids(public_id,customer_user_id,status,created_at_ms) SELECT ?,id,'active',? FROM users WHERE id=? AND account_role='customer' AND deleted_at_ms IS NULL RETURNING public_id").bind(id,now,userId),
 ]);
 if(results[1].results.length!==1) throw new HttpError(401,'AUTH_REQUIRED','auth.required');
 return qrJson(id);
}
// Internal lookup for D07; callers must authorize the owner's shop before exposing a label.
export async function activeQrCustomer(db:D1Database,id:string):Promise<string> {
 if(!/^[0-9a-f]{64}$/.test(id)) throw new HttpError(400,'QR_INVALID','qr.invalid');
 const row=await db.prepare("SELECT q.status,q.customer_user_id FROM customer_qr_ids q JOIN users u ON u.id=q.customer_user_id WHERE q.public_id=? AND u.account_role='customer' AND u.deleted_at_ms IS NULL").bind(id).first<{status:string;customer_user_id:string}>();
 if(!row) throw new HttpError(400,'QR_INVALID','qr.invalid');
 if(row.status!=='active') throw new HttpError(400,'QR_REVOKED','qr.revoked');
 return row.customer_user_id;
}
