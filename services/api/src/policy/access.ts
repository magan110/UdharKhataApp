import type { Principal } from '../auth/authenticator';
import { HttpError } from '../http/errors';

export function requirePrincipal(principal: Principal | null): Principal {
  if (!principal) throw new HttpError(401, 'AUTH_REQUIRED', 'auth.required');
  return principal;
}

export function requireRole(principal: Principal | null, role: Principal['role']): Principal {
  const authenticated = requirePrincipal(principal);
  if (authenticated.role !== role) throw new HttpError(403, 'FORBIDDEN', 'auth.forbidden');
  return authenticated;
}

export async function requireOwnedShop(db:D1Database,principal:Principal,shopId:string) {
  const row=await db.prepare("SELECT s.* FROM shops s JOIN users u ON u.id=s.owner_user_id WHERE s.id=? AND s.owner_user_id=? AND s.status='active' AND u.account_role='owner' AND u.deleted_at_ms IS NULL")
    .bind(shopId,principal.userId).first<{id:string;name:string;status:'active';created_at_ms:number}>();
  if(principal.role!=='owner' || !row) throw new HttpError(404,'NOT_FOUND','api.notFound');
  return row;
}
export async function requireRelationship(db:D1Database,principal:Principal,shopId:string,linkId:string) {
  const row=await db.prepare("SELECT l.id,l.customer_user_id FROM shop_customers l JOIN shops s ON s.id=l.shop_id JOIN users c ON c.id=l.customer_user_id JOIN users o ON o.id=s.owner_user_id WHERE l.id=? AND l.shop_id=? AND l.status='active' AND s.status='active' AND c.deleted_at_ms IS NULL AND o.deleted_at_ms IS NULL AND ((?='owner' AND s.owner_user_id=?) OR (?='customer' AND l.customer_user_id=?))")
    .bind(linkId,shopId,principal.role,principal.userId,principal.role,principal.userId).first<{id:string;customer_user_id:string}>();
  if(!row) throw new HttpError(404,'NOT_FOUND','api.notFound');
  return row;
}
export async function requireEntry(db:D1Database,principal:Principal,shopId:string,linkId:string,entryId:string) {
  await requireRelationship(db,principal,shopId,linkId);
  const row=await db.prepare('SELECT id FROM ledger_entries WHERE id=? AND shop_id=? AND shop_customer_id=?').bind(entryId,shopId,linkId).first<{id:string}>();
  if(!row) throw new HttpError(404,'NOT_FOUND','api.notFound');
  return row;
}
