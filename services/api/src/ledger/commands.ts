import type { Principal } from '../auth/authenticator';
import { hashToken } from '../auth/sessions';
import { commitEntry } from '../db/transaction';
import { findReceipt, type OperationReceipt } from '../db/queries';
import { HttpError } from '../http/errors';
import { requireOwnedShop, requireRelationship } from '../policy/access';
import { CREDIT_LIMITS } from './limits';
export interface CreditCommand {clientOperationId:string;linkId:string;kind:'credit';amountPaise:number;note:string|null;dueDate:string|null;occurredAtMs:number}
interface EntryRow {id:string;server_seq:number;shop_id:string;shop_customer_id:string;kind:string;amount_paise:number;effect_paise:number;note:string|null;due_date:string|null;occurred_at_ms:number;created_at_ms:number;created_by_user_id:string}
export async function postCredit(db:D1Database,principal:Principal,shopId:string,command:CreditCommand) {
 await requireOwnedShop(db,principal,shopId);
 await requireRelationship(db,principal,shopId,command.linkId);
 const requestHash=await hashToken(JSON.stringify([principal.userId,shopId,command.kind,command.linkId,command.amountPaise,command.note,command.dueDate,command.occurredAtMs]));
 const recover=async(receipt:OperationReceipt,replayed:boolean)=>{
  if(receipt.request_hash!==requestHash || !receipt.entry_id) throw new HttpError(409,'IDEMPOTENCY_CONFLICT','api.idempotencyConflict');
  // Current access is required even when the receipt predates access removal.
  await requireRelationship(db,principal,shopId,command.linkId);
  const e=await db.prepare('SELECT * FROM ledger_entries WHERE id=? AND shop_id=? AND shop_customer_id=? AND created_by_user_id=?').bind(receipt.entry_id,shopId,command.linkId,principal.userId).first<EntryRow>();
  if(!e) throw new HttpError(404,'NOT_FOUND','api.notFound');
  return {entry:{id:e.id,serverSeq:e.server_seq,shopId:e.shop_id,linkId:e.shop_customer_id,kind:e.kind,amountPaise:e.amount_paise,targetAmountPaise:null,effectPaise:e.effect_paise,note:e.note,paymentMethod:null,dueDate:e.due_date,correctsEntryId:null,revision:0,correctionReason:null,occurredAtMs:e.occurred_at_ms,createdAtMs:e.created_at_ms,createdByUserId:e.created_by_user_id},balance:{balancePaise:receipt.response_balance_paise,ledgerVersion:receipt.response_version,asOfServerSeq:e.server_seq,asOfAtMs:e.created_at_ms},replayed};
 };
 const existing=await findReceipt(db,shopId,command.clientOperationId);
 if(existing)return recover(existing,true);
 const now=Date.now();
 if(command.occurredAtMs>now+CREDIT_LIMITS.maxFutureSkewMs || command.occurredAtMs<now-CREDIT_LIMITS.maxClockSkewMs)throw new HttpError(400,'VALIDATION_ERROR','credit.clockInvalid');
 const id=crypto.randomUUID();
 const statement=db.prepare(`INSERT INTO ledger_entries(id,shop_customer_id,shop_id,customer_user_id,kind,amount_paise,effect_paise,note,due_date,created_by_user_id,client_operation_id,occurred_at_ms,created_at_ms)
 SELECT ?,l.id,l.shop_id,l.customer_user_id,'credit',?,?,?,?,?,?,?,? FROM shop_customers l WHERE l.id=? AND l.shop_id=?`)
 .bind(id,command.amountPaise,command.amountPaise,command.note,command.dueDate,principal.userId,command.clientOperationId,command.occurredAtMs,now,command.linkId,shopId);
 try {
  const receipt=await commitEntry(db,statement,{shopId,operationId:command.clientOperationId,requestHash,entryId:id,createdAtMs:now});
  return recover(receipt,receipt.entry_id!==id);
 } catch(error) {
  const message=error instanceof Error?error.message:'';
  if(message.includes('IDEMPOTENCY_CONFLICT'))throw new HttpError(409,'IDEMPOTENCY_CONFLICT','api.idempotencyConflict');
  if(message.includes('BALANCE_CONFLICT'))throw new HttpError(409,'BALANCE_CONFLICT','credit.balanceLimit');
  await requireOwnedShop(db,principal,shopId);
  await requireRelationship(db,principal,shopId,command.linkId);
  throw error;
 }
}
export async function readBalance(db:D1Database,principal:Principal,shopId:string,linkId:string) {
 await requireRelationship(db,principal,shopId,linkId);
 const row=await db.prepare(`SELECT a.balance_paise,a.version,a.updated_at_ms,COALESCE((SELECT MAX(e.server_seq) FROM ledger_entries e WHERE e.shop_customer_id=l.id),0) AS seq
 FROM ledger_accounts a JOIN shop_customers l ON l.id=a.shop_customer_id JOIN shops s ON s.id=l.shop_id JOIN users c ON c.id=l.customer_user_id JOIN users o ON o.id=s.owner_user_id
 WHERE l.id=? AND l.shop_id=? AND l.status='active' AND s.status='active' AND c.deleted_at_ms IS NULL AND o.deleted_at_ms IS NULL AND ((?='owner' AND s.owner_user_id=?) OR (?='customer' AND l.customer_user_id=?))`).bind(linkId,shopId,principal.role,principal.userId,principal.role,principal.userId).first<{balance_paise:number;version:number;updated_at_ms:number;seq:number}>();
 if(!row)throw new HttpError(404,'NOT_FOUND','api.notFound');
 return {balancePaise:row.balance_paise,ledgerVersion:row.version,asOfServerSeq:row.seq,asOfAtMs:row.updated_at_ms};
}
