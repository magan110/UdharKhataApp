export interface OperationReceipt {
  shop_id: string;
  client_operation_id: string;
  request_hash: string;
  entry_id: string | null;
  shop_customer_id: string | null;
  response_version: number | null;
  response_balance_paise: number | null;
}

// The caller must authorize the shop before looking up a receipt.
export function findReceipt(db: D1Database, shopId: string, operationId: string) {
  return db.prepare(`SELECT shop_id,client_operation_id,request_hash,entry_id,
    shop_customer_id,response_version,response_balance_paise FROM sync_operations
    WHERE shop_id=? AND client_operation_id=?`).bind(shopId, operationId).first<OperationReceipt>();
}
