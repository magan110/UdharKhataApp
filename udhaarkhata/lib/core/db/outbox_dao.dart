import '../network/contracts.dart';
import 'database.dart';

final class OutboxDao {
  const OutboxDao(this.database, this.accountId);
  final SqliteAccountDatabase database;
  final OpaqueId accountId;

  Future<List<Map<String, Object?>>> entries() => database.transaction(
    accountId,
    (tx) => tx.rawQuery('SELECT * FROM outbox ORDER BY rowid'),
  );
  Future<List<Map<String, Object?>>> ready(
    DateTime now, {
    required String shopId,
  }) => database.transaction(accountId, (tx) async {
    final rows = await tx.rawQuery(
      'SELECT o.*,l.shop_id FROM outbox o JOIN cached_links l ON l.id=o.link_id WHERE l.shop_id=? ORDER BY o.rowid',
      [shopId],
    );
    final blocked = <String>{};
    final ready = <Map<String, Object?>>[];
    for (final row in rows) {
      final link = row['link_id'] as String;
      final retry = row['retry_at_ms'] as int?;
      if (row['state'] != 'pending' ||
          (retry != null && retry > now.millisecondsSinceEpoch)) {
        blocked.add(link);
      }
      if (!blocked.contains(link)) ready.add(row);
    }
    return ready;
  });
}
