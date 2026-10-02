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
}
