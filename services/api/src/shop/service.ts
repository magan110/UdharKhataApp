import type { Principal } from '../auth/authenticator';
import { HttpError } from '../http/errors';
import { requireRole } from '../policy/access';
interface ShopRow { id:string; name:string; status:'active'|'closed'; created_at_ms:number }
export const shopJson=(row:ShopRow)=>({id:row.id,name:row.name,status:row.status,createdAtMs:row.created_at_ms});
export async function createShop(db:D1Database,principal:Principal,name:string) {
  requireRole(principal,'owner');
  const result=await db.prepare("INSERT INTO shops(id,owner_user_id,name,status,created_at_ms) SELECT ?,id,?,'active',? FROM users WHERE id=? AND account_role='owner' AND deleted_at_ms IS NULL ON CONFLICT(owner_user_id) DO NOTHING RETURNING id")
    .bind(crypto.randomUUID(),name,Date.now(),principal.userId).all();
  const row=await db.prepare("SELECT s.* FROM shops s JOIN users u ON u.id=s.owner_user_id WHERE s.owner_user_id=? AND u.deleted_at_ms IS NULL AND u.account_role='owner'").bind(principal.userId).first<ShopRow>();
  if(!row) throw new HttpError(401,'AUTH_REQUIRED','auth.required');
  if(row.status!=='active') throw new HttpError(409,'SHOP_ALREADY_EXISTS','shop.closed');
  return {shop:shopJson(row),created:result.results.length===1};
}
export async function shopSummary(db:D1Database,principal:Principal) {
  if(principal.role==='owner') {
    const row=await db.prepare("SELECT * FROM shops WHERE owner_user_id=? AND status='active'").bind(principal.userId).first<ShopRow>();
    return {shop:row?shopJson(row):null};
  }
  // ponytail: first 100 profile links; D10 ledger listing supplies the full browsing contract.
  const rows=await db.prepare("SELECT l.id,l.shop_id,s.name,a.balance_paise,a.version FROM shop_customers l JOIN ledger_accounts a ON a.shop_customer_id=l.id JOIN shops s ON s.id=l.shop_id JOIN users o ON o.id=s.owner_user_id WHERE l.customer_user_id=? AND l.status='active' AND s.status='active' AND o.deleted_at_ms IS NULL ORDER BY l.id LIMIT 101").bind(principal.userId).all<{id:string;shop_id:string;name:string;balance_paise:number;version:number}>();
  return {links:rows.results.slice(0,100).map(row=>({id:row.id,shopId:row.shop_id,shopName:row.name,balancePaise:row.balance_paise,ledgerVersion:row.version})),linksHasMore:rows.results.length>100};
}
