import type { Principal } from '../auth/authenticator';
import { requireOwnedShop } from '../policy/access';
import { activeQrCustomer } from './service';
import { HttpError } from '../http/errors';

export async function resolveCustomer(db: D1Database, principal: Principal, shopId: string, publicQrId: string) {
  await requireOwnedShop(db, principal, shopId);
  const customerId = await activeQrCustomer(db, publicQrId);
  const row = await db.prepare(`SELECT u.display_name,l.id,l.status FROM users u
    LEFT JOIN shop_customers l ON l.customer_user_id=u.id AND l.shop_id=?
    WHERE u.id=? AND u.deleted_at_ms IS NULL AND u.account_role='customer'`)
    .bind(shopId, customerId).first<{display_name:string;id:string|null;status:string|null}>();
  if (!row) throw new HttpError(400, 'QR_INVALID', 'qr.invalid');
  if (row.status === 'access_removed') throw new HttpError(404, 'NOT_FOUND', 'api.notFound');
  return {state:row.id?'linked':'new',customerDisplayName:row.display_name,linkId:row.id};
}
