import { findReceipt, type OperationReceipt } from './queries';

interface EntryReceiptInput {
  shopId: string;
  operationId: string;
  requestHash: string;
  entryId: string;
  createdAtMs: number;
}

function replay(receipt: OperationReceipt, requestHash: string) {
  if (receipt.request_hash !== requestHash) throw new Error('IDEMPOTENCY_CONFLICT');
  return receipt;
}

// Only called after authentication, shop authorization and command validation.
// Triggers recheck ownership, active relationships, balance and revision at commit.
export async function commitEntry(db: D1Database, entry: D1PreparedStatement, input: EntryReceiptInput) {
  const existing = await findReceipt(db, input.shopId, input.operationId);
  if (existing) return replay(existing, input.requestHash);
  try {
    await db.batch([
      entry,
      db.prepare(`INSERT INTO sync_operations
        (shop_id,client_operation_id,operation_kind,request_hash,entry_id,response_version,response_balance_paise,created_at_ms)
        SELECT e.shop_id,e.client_operation_id,'entry',?,e.id,a.version,a.balance_paise,?
        FROM ledger_entries e JOIN ledger_accounts a ON a.shop_customer_id=e.shop_customer_id
        WHERE e.id=? AND e.shop_id=? AND e.client_operation_id=?`)
        .bind(input.requestHash, input.createdAtMs, input.entryId, input.shopId, input.operationId),
      // Force rollback if the SELECT above found no matching inserted entry.
      db.prepare(`INSERT INTO sync_operations (shop_id,client_operation_id,operation_kind,request_hash,created_at_ms)
        SELECT ?,?,'entry',?,? WHERE NOT EXISTS (SELECT 1 FROM sync_operations WHERE shop_id=? AND client_operation_id=?)`)
        .bind(input.shopId, input.operationId, input.requestHash, input.createdAtMs, input.shopId, input.operationId),
    ]);
  } catch (error) {
    // A concurrent duplicate may have won after our pre-read.
    const receipt = await findReceipt(db, input.shopId, input.operationId);
    if (receipt) return replay(receipt, input.requestHash);
    throw error;
  }
  const receipt = await findReceipt(db, input.shopId, input.operationId);
  if (!receipt) throw new Error('RECEIPT_MISSING');
  return replay(receipt, input.requestHash);
}
