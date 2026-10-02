import '../network/contracts.dart';
import '../../features/qr/owner_qr_model.dart';
import 'database.dart';

/// Only server-verified, active relationships are eligible for offline lookup.
class QrLinkDao {
  const QrLinkDao(this.database, this.accountId);
  final SqliteAccountDatabase database;
  final OpaqueId accountId;

  Future<void> cache(String publicId, CustomerLink link) =>
      database.transaction(accountId, (tx) async {
        final account = (await tx.query('local_account')).single;
        if (account['role'] != 'owner' ||
            account['last_verified_at_ms'] == null) {
          throw StateError('Verified owner required');
        }
        final existing = await tx.query(
          'cached_links',
          where: 'id=?',
          whereArgs: [link.id.value],
        );
        final values = <String, Object?>{
          'id': link.id.value,
          'shop_id': link.shopId.value,
          'customer_user_id': link.customerId.value,
          'owner_user_id': accountId.value,
          'verified_qr_id': publicId,
          'status': 'active',
          'last_verified_at_ms': DateTime.now().millisecondsSinceEpoch,
          'display_name': link.displayName,
          'nickname': link.nickname,
          'linked_at_ms': link.linkedAtMs,
        };
        if (existing.isEmpty) {
          await tx.insert('cached_links', values);
        } else {
          if (existing.single['owner_user_id'] != accountId.value ||
              existing.single['shop_id'] != link.shopId.value ||
              existing.single['customer_user_id'] != link.customerId.value) {
            throw StateError('Link scope changed');
          }
          await tx.update(
            'cached_links',
            values,
            where: 'id=?',
            whereArgs: [link.id.value],
          );
        }
      });

  Future<CustomerLink?> lookup(
    String shopId, {
    String? publicId,
    String? linkId,
  }) => database.transaction(accountId, (tx) async {
    final account = (await tx.query('local_account')).single;
    if (account['role'] != 'owner' || account['last_verified_at_ms'] == null) {
      throw StateError('Verified owner required');
    }
    final rows = await tx.rawQuery(
      'SELECT l.*,s.balance_paise,s.ledger_version FROM cached_links l JOIN owner_ledger_snapshots s ON s.link_id=l.id WHERE l.shop_id=? AND l.owner_user_id=? AND l.status=? AND l.${publicId != null ? 'verified_qr_id' : 'id'}=?',
      [shopId, accountId.value, 'active', publicId ?? linkId],
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    return CustomerLink(
      id: OpaqueId.fromJson(r['id']),
      shopId: OpaqueId.fromJson(r['shop_id']),
      customerId: OpaqueId.fromJson(r['customer_user_id']),
      displayName: r['display_name'] as String,
      nickname: r['nickname'] as String?,
      linkedAtMs: r['linked_at_ms'] as int,
      balance: MoneyPaise.fromJson(r['balance_paise']),
      version: r['ledger_version'] as int,
    );
  });

  Future<void> invalidate(
    String shopId, {
    String? publicId,
    String? linkId,
    bool removeAccess = false,
  }) => database.transaction(
    accountId,
    (tx) => tx.update(
      'cached_links',
      {'verified_qr_id': null, if (removeAccess) 'status': 'access_removed'},
      where:
          'shop_id=? AND owner_user_id=? AND ${publicId != null ? 'verified_qr_id' : 'id'}=?',
      whereArgs: [shopId, accountId.value, publicId ?? linkId],
    ),
  );
}
