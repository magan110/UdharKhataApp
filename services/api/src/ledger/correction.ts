import type {Principal} from '../auth/authenticator';
import {hashToken} from '../auth/sessions';
import {commitEntry} from '../db/transaction';
import {findReceipt,type OperationReceipt} from '../db/queries';
import {HttpError} from '../http/errors';
import {requireOwnedShop,requireRelationship} from '../policy/access';
import {readBalance} from './commands';
import {CREDIT_LIMITS} from './limits';
export interface CorrectionCommand {clientOperationId:string;linkId:string;kind:'correction';correctsEntryId:string;targetAmountPaise:number;expectedRevision:number;correctionReason:string;occurredAtMs:number}
interface Row {id:string;server_seq:number;shop_id:string;shop_customer_id:string;target_amount_paise:number;effect_paise:number;corrects_entry_id:string;expected_revision:number;correction_reason:string;occurred_at_ms:number;created_at_ms:number;created_by_user_id:string}
export async function postCorrection(db:D1Database,principal:Principal,shopId:string,command:CorrectionCommand){
 await requireOwnedShop(db,principal,shopId);await requireRelationship(db,principal,shopId,command.linkId);
 const requestHash=await hashToken(JSON.stringify([principal.userId,shopId,command.kind,command.linkId,command.correctsEntryId,command.targetAmountPaise,command.expectedRevision,command.correctionReason,command.occurredAtMs]));
 const recover=async(receipt:OperationReceipt,replayed:boolean)=>{
  if(receipt.request_hash!==requestHash||!receipt.entry_id)throw new HttpError(409,'IDEMPOTENCY_CONFLICT','api.idempotencyConflict');
  await requireOwnedShop(db,principal,shopId);await requireRelationship(db,principal,shopId,command.linkId);
  const e=await db.prepare('SELECT * FROM ledger_entries WHERE id=? AND shop_id=? AND shop_customer_id=? AND created_by_user_id=?').bind(receipt.entry_id,shopId,command.linkId,principal.userId).first<Row>();
  if(!e)throw new HttpError(404,'NOT_FOUND','api.notFound');
  return {entry:{id:e.id,serverSeq:e.server_seq,shopId:e.shop_id,linkId:e.shop_customer_id,kind:'correction',amountPaise:null,targetAmountPaise:e.target_amount_paise,effectPaise:e.effect_paise,note:null,paymentMethod:null,dueDate:null,correctsEntryId:e.corrects_entry_id,revision:e.expected_revision+1,correctionReason:e.correction_reason,occurredAtMs:e.occurred_at_ms,createdAtMs:e.created_at_ms,createdByUserId:e.created_by_user_id},balance:{balancePaise:receipt.response_balance_paise,ledgerVersion:receipt.response_version,asOfServerSeq:e.server_seq,asOfAtMs:e.created_at_ms},replayed};
 };
 const existing=await findReceipt(db,shopId,command.clientOperationId);if(existing)return recover(existing,true);
 const target=await db.prepare("SELECT e.kind,f.revision FROM ledger_entries e JOIN entry_effective f ON f.entry_id=e.id WHERE e.id=? AND e.shop_id=? AND e.shop_customer_id=? AND e.kind IN ('credit','payment')").bind(command.correctsEntryId,shopId,command.linkId).first<{kind:string;revision:number}>();
 if(!target)throw new HttpError(404,'NOT_FOUND','api.notFound');
 const now=Date.now();if(command.occurredAtMs>now+CREDIT_LIMITS.maxFutureSkewMs)throw new HttpError(400,'VALIDATION_ERROR','credit.clockInvalid');
 const id=crypto.randomUUID();
 const statement=db.prepare(`INSERT INTO ledger_entries(id,shop_customer_id,shop_id,customer_user_id,kind,target_amount_paise,effect_paise,corrects_entry_id,expected_revision,correction_reason,created_by_user_id,client_operation_id,occurred_at_ms,created_at_ms)
 SELECT ?,e.shop_customer_id,e.shop_id,e.customer_user_id,'correction',?,(CASE e.kind WHEN 'credit' THEN ? ELSE -? END)-f.effective_paise,e.id,?,?,?,?,?,? FROM ledger_entries e JOIN entry_effective f ON f.entry_id=e.id WHERE e.id=? AND e.shop_id=? AND e.shop_customer_id=?`)
 .bind(id,command.targetAmountPaise,command.targetAmountPaise,command.targetAmountPaise,command.expectedRevision,command.correctionReason,principal.userId,command.clientOperationId,command.occurredAtMs,now,command.correctsEntryId,shopId,command.linkId);
 try{const receipt=await commitEntry(db,statement,{shopId,operationId:command.clientOperationId,requestHash,entryId:id,createdAtMs:now});return recover(receipt,receipt.entry_id!==id);}
 catch(error){await requireOwnedShop(db,principal,shopId);await requireRelationship(db,principal,shopId,command.linkId);const message=error instanceof Error?error.message:'';
  if(message.includes('CORRECTION_INVALID'))throw new HttpError(409,'REVISION_CONFLICT','correction.revisionConflict');
  if(message.includes('IDEMPOTENCY_CONFLICT'))throw new HttpError(409,'IDEMPOTENCY_CONFLICT','api.idempotencyConflict');
  if(message.includes('BALANCE_CONFLICT'))throw new HttpError(409,'BALANCE_CONFLICT','payment.balanceConflict',false,{}, {balance:await readBalance(db,principal,shopId,command.linkId)});
  throw error;
 }
}
